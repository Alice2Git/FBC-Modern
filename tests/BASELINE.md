# fbc test-suite baseline (before any ustring compiler changes)

Captured against `src` with **Phase 0 only** (new rtlib files, which are not yet
reachable from any FB source) — so this is effectively the stock 1.20.0 tree.

```
1154412 assertions   1154401 passed   11 failed   2302 modules
```

## The 11 failures, and why they are not regressions

| Module | Failed | Cause |
|---|---|---|
| `fbc_tests.threads.threadcall_` | 11 / 11 | Built with `-DDISABLE_FFI` |

`libffi` is not installed in this environment, so the rtlib is built with `-DDISABLE_FFI`.
That does not remove `fb_ThreadCall` — `src/rtlib/thread_call.c:25` compiles it to
`return NULL` — so everything links, but every `ThreadCall` assertion fails. Nothing else
in the suite is affected.

**Any future run must show exactly these 11 failures and no others.** A 12th failure, or a
failure in any other module, is a regression introduced by the ustring work.

## Reproducing

Two environment workarounds are required; neither is related to ustring.

1. **Run the tests makefile directly, with native Windows paths.** The root makefile does
   ``cd tests && $(MAKE) unit-tests FBC="`pwd`/../$(FBC_EXE) -i `pwd`/../inc"``. Under Git Bash
   `pwd` yields `/c/dev/...`, which only resolves because Git Bash rewrites POSIX paths when it
   invokes a native binary. Make runs its recipes through `cmd.exe`, which does not, so fbc
   receives a literal `/c/dev/...` and every `#include` fails with `error 23: File not found`.
   Bypass it:

   ```
   cd tests && make unit-tests FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc"
   ```

2. **A stub `libffi.a`.** fbc emits `-lffi` whenever a `ThreadCall` appears
   (`rtl-system.bas:787`), regardless of how the rtlib was built, so the final link needs the
   name to resolve even though `DISABLE_FFI` means no ffi symbol is ever referenced:

   ```
   ar rcs lib/freebasic/win64/libffi.a <any-empty-object>
   ```

`gfxlib2` must also be built (`make gfxlib2`) — the suite links `-lfbgfxmt`.

## There are THREE test targets, not one

`unit-tests` is the one everyone runs, and it is not the whole suite - it holds
670 of the 2515 `.bas` files. The root makefile also has:

| Target | What it is | Scale |
|---|---|---|
| `unit-tests` | fbcunit assertions | 670 modules, 1154412 assertions |
| `log-tests` | compile-and-run, **per dialect** | 1687 tests across fb / fblite / qb / deprecated |
| `warning-tests` | exact compiler diagnostics, **per target** | 68 files x 5 targets = 340 runs |

All three matter for a change like this. `log-tests` is the only thing that
exercises `-lang qb`, where USTRING must NOT be a keyword; `warning-tests`
compiles for **dos, linux-x86, linux-x86_64, win32 and win64** (with `-r`, so no
cross-assembler is needed) and is the only cross-target coverage available here.

### Running them

```
cd tests && make log-tests FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc -p C:/dev/utils/mingw64/lib"
cd tests/warnings && FBC="C:/dev/FBC-Modern/src/bin/fbc.exe" bash ./test.sh
```

Two environment notes, neither related to ustring:

1. **`-p C:/dev/utils/mingw64/lib`** - without it the four `cpp/*` log-tests fail
   with `cannot find -lstdc++`. `libstdc++.a` exists in that directory but not in
   the gcc lib directory the linker searches. Adding the path makes all four
   link and run.
2. **`warning-tests` is a git-diff test.** `test.sh` regenerates
   `tests/warnings/r/<target>/*.txt` and you check with `git diff` whether
   anything moved. On Windows the regenerated files may differ only in line
   endings, which `git diff` normalises away - compare content, not `git status`.

## Trap: `clean-tests` is a ROOT makefile target

`clean-tests` is defined in `src/makefile`, **not** in `tests/Makefile`.
Running `make clean-tests` from inside `tests/` silently does nothing, and since
the `.bas` sources have not changed, make then treats all ~670 `.o` files as up
to date and re-runs the *previous* `fbc-tests.exe` unchanged.

The result looks like a passing regression run but proves nothing. To force a
real rebuild:

```
find tests -name "*.o" -delete
rm -f tests/fbc-tests.exe tests/unit-tests.inc tests/unit-tests-obj.lst
```

Confirm it actually rebuilt by checking the compile count in the log — it should
be ~670, not 1.

## The LLVM backend needs a shim, for pre-existing reasons

`fbc -gen llvm` drives `llc`, which a clang-only install does not ship, and the
IR it emits is several LLVM releases out of date. `sh tools/check_llvm.sh`
works around both and diffs the result against `-gen gcc`. None of the three
blocking constructs is ustring's — a plain `STRING` program reproduces all of
them. Details in `NOTES.md`.

## Build commands used

```
make rtlib    CFLAGS="-Wfatal-errors -O2 -fno-exceptions -fno-unwind-tables -fno-asynchronous-unwind-tables -DDISABLE_FFI"
make gfxlib2  CFLAGS="-Wfatal-errors -O2 -DDISABLE_FFI"
make compiler FBC=<bootstrap fbc 1.10.1>
```

A third environment fix lives in the tree itself: `makefile` matched `MSYS_NT` when choosing the
short `ar` command line, which missed `MINGW64_NT` and made the ~17 KB argument list overflow
`cmd.exe`'s limit. Changed to match `_NT`. That is a **separate, pre-existing bug**, not part of
the ustring feature, and should be its own upstream commit.

---

# Gate protocol (generics, FOR EACH, containers)

Added after the USTRING work. Everything above still applies; this is what the
later phases learned on top of it.

## There are FOUR test targets now

`tests/errors/` was added by this work and runs the same way `tests/warnings/`
does — regenerate, then `git diff` the reference tree.

```
cd tests/errors   && FBC="C:/dev/FBC-Modern/src/bin/fbc.exe" bash ./test.sh
cd tests/warnings && FBC="C:/dev/FBC-Modern/src/bin/fbc.exe" bash ./test.sh
```

**Golden error files hold ONE case each.** The compiler stops at the first error
in many situations, so a file with several cases reports only the first and the
rest are never checked.

## The environmental floor

**THE FLOOR IS PER-BACKEND. It is not the same number under gcc and gas64.**

| Backend | Unit-test failures | Which |
|---|---|---|
| gcc (default) | **11** | `threads.threadcall_` |
| `GEN=gas64` | **12** | `threads.threadcall_` (11) + `string_.fbstr_split` (1) |

Plus **4 `cpp` log-test failures** under both. The 11 are `-DDISABLE_FFI`
(above); the 4 are a missing `libstdc++` in this mingw64, proven by rebuilding at
HEAD with the changes stashed.

So a 12th failure under gcc is a regression; under gas64 a **13th** is, and the
12th is only a regression if it is not `fbstr_split`.

### The gas64 `fbstr_split` failure is a REAL BUG, not an environment gap

Unlike the other floor entries, this one is a defect in this tree. It is parked
rather than fixed only because it is unrelated to the work in flight.

`FB.Split`'s third argument -- the `boolean` case-insensitivity flag -- is
miscompiled by the gas64 backend. The default is ignored AND an explicit `false`
is ignored, so the function always behaves case-insensitively:

```freebasic
#include once "fb/string.bi"
#include once "fb/array.bi"
using FB
print Split( "aXbXc", "x" ).Count( )           '' gcc 1   gas64 3
print Split( "aXbXc", "x", true ).Count( )     '' gcc 3   gas64 3
print Split( "aXbXc", "x", false ).Count( )    '' gcc 1   gas64 3
```

It fails `string/fbstr_split.bas(113)`. Wrong code, not a diagnostic, and it is
the shipped default backend for day-to-day builds -- so anything relying on a
case-sensitive `Split` is wrong under gas64 today.

**How this was missed:** the floor of 11 was recorded from a **gcc** run, and the
"both backends" claim in the string-library section below was not separately
reconciled per backend. Confirmed pre-existing by stashing the generics-lookup
fix, rebuilding, and reproducing identically -- it is not caused by that change.

## Reconcile the log-test count — do not just read "no failures"

`passed + failed = total logs`, and `passed` should move by exactly the number
of tests added. The count after the generics work was
**1727 passed / 4 failed / 1731 logs**.

After `Optional` and `Result` (8 new files in `src/tests/generics/`) it is
**1740 passed / 0 failed / 1740 logs**, measured WITH `-p C:/dev/utils/mingw64/lib`
— that flag is what turns the 4 `cpp` failures into passes, so quote the flag
alongside the number or the two figures look like a regression in either
direction.

Count the logs with:

```
find tests -name "*.log" ! -name "log-tests-results*" ! -name "failed-*"
```

The four `failed-<lang>.log` aggregates are not test logs and inflate a naive
count by four. Also check that no log is missing its `RESULT=` line — a
timed-out run leaves one truncated, and it reads as neither passed nor failed.

**Never run two `make log-tests` concurrently.** They race and invent failures.

## New tests are not picked up automatically

- A new test **FILE** in an existing directory needs `make clean-tests` **from
  `src/`** — the generated list is cached. This silently hid two tests behind a
  green-looking gate.
- A new test **DIRECTORY** needs an entry in `tests/dirlist.mk` *and* a
  `make clean`.

## Run behaviour tests under BOTH backends, by hand

`GEN=gas64` as well as the default gcc. Three separate defects in this work were
visible to only one backend:

- an emission-order bug invisible to gas64;
- a stale-stack bug that was a C compile error under gcc and a segfault under
  gas64;
- a weak-external bug that compiled, linked and silently returned the **wrong
  function** under gcc.

## Two smaller traps

- **Delete the old `.exe` before every probe.** A stale binary has twice
  produced output that looked like a passing fix.
- **An unexpected result is more often the test than the compiler.** `base`,
  `Fix` and `Mid` are reserved; `A`/`a` collide case-insensitively; `K` cannot
  be a parameter type; `long + long` promotes to INTEGER; a UDT FOR variable
  needs a default constructor; `x is T` needs a genuine downcast. Check the
  plain-FreeBASIC control before concluding the compiler is wrong.

## Build invocation

The makefile root is **`src/`**. `make` from the repository root reports
"No rule to make target 'compiler'".

```
cd src && make compiler -j8 FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc"
```

A full compiler rebuild is ~6 s at `-j8` (146 modules); touching any `.bi`
rebuilds everything.

## FB string library (`fb/string.bi`) — baseline after phases 0–6

Added by the string-library work, on branch `feat/fb-string-library`.

```
1155921 assertions   1155910 passed   11 failed   2398 modules
```

The 11 are the same `fbc_tests.threads.threadcall_` failures documented above —
`libffi` absent — and no others. **Any 12th failure is a regression.**

That figure is the **gcc** run. Under `GEN=gas64` the same tree reports **12
failed**, the extra one being `string_.fbstr_split` — a real gas64 miscompile of
Split's `boolean` argument, documented under "The environmental floor" above.

The delta from the 1,154,420 baseline is 1,501 assertions across five new suites
in `src/tests/string/`:

| Suite | Assertions | Covers |
|---|---|---|
| `fbstr_search` | 207 | Tally, TallyChars, InstrChars, VerifySet, SpanOf, StartsWith, EndsWith, Contains |
| `fbstr_extract` | 186 | Extract, Remain, Between, Clip, DeleteAt, InsertAt and their `*Chars` forms |
| `fbstr_transform` | 205 | Replace, Remove, Retain, Reverse, Repeat, Shrink, MCase, RemoveBetween |
| `fbstr_pad` | 693 | pad, wrap, escape/unescape, IsNumeric, IsBlank |
| `fbstr_split` | 151 | Split, SplitChars, Join |
| `ustr_concat_ops` | 59 | the `&`-operator ustring fix, and the `&=` wstring-width fix (see below) |

`src/tests/string/fbstr_split_mod2.bas` has no assertions of its own: it is a
SECOND module including `fb/string.bi`, so that dropping the `private` on the
Split/Join bodies breaks the BUILD rather than a test.

`src/tests/generics/namespace-qualified-inst.bas` is a log-test, not an fbcunit
suite, so it appears in the log-tests count (1,732, up from 1,731) rather than
here.

### Two compiler bugs fixed along the way

Both pre-existing, both silent, both found by tests written for something else:

- **Namespace-qualified generic instantiation.** `dim x as FB.Array( of string )`
  did not compile; the replay resolved the generic body in the caller's scope
  rather than the generic's declaring namespace. Pinned by
  `src/tests/generics/namespace-qualified-inst.bas`.
- **`&` sent a ustring operand through the C locale.** `someWstring & someUstring`
  destroyed non-BMP text. Pinned by `src/tests/string/ustr_concat_ops.bas`,
  which was verified to FAIL without the fix (12 of its 50 assertions) rather
  than merely to pass with it.

### Cross-platform: now RUN, not just compiled

The Linux gap recorded in the first version of this section is CLOSED. All three
shipped compilers were rebuilt and the string suites were executed under each:

| Target | How | Result |
|---|---|---|
| win64 | full gate, gcc | 1,155,921 / 11 failed (the libffi baseline) |
| win64 | full gate, gas64 | 1,155,921 / **12** failed — the 11 plus the `fbstr_split` gas64 miscompile; this row originally claimed 11 for both backends and was wrong |
| win32 | string suites under the rebuilt **shipped** `fbc32.exe` | **1,501 / 1,501** |
| linux-x86_64 | string suites under the natively-built **shipped** `fbc` (WSL2) | **1,501 / 1,501** |

Running them found **two more bugs that Windows alone could never show**, both
now fixed and pinned:

- **The whole WSTRING family returned EMPTY on Linux.** `hUStrArg`/`hStrArg` read
  the descriptor's `->len` raw, but the temp flag lives in that field's sign bit
  — `fb_ustring.h` says so outright. On Linux `hWstrArg` goes through
  `fb_WstrToUStr`, which returns a **temp** descriptor, so the raw read came back
  negative and every wstring call saw an empty string. Windows never hit it: a
  16-bit `wchar_t` is reinterpreted, not converted, so no temporary is involved.
  Fixed by using `FB_STRSIZE`/`FB_USTRSIZE`.
- **`ustring &= wstring` dropped characters on Linux** — pre-existing, not from
  this work. `rtlUStrConcatAssign` handed a WSTRING straight to a ustring entry
  point that unpacks 16-bit units, so a 32-bit buffer was reinterpreted: `"pq"`
  (`70 00 00 00 71 00 00 00`) read as `p` then NUL, and `u &= w` produced
  `"xyp"`. `astUpdStrConcat` already converted for the BOP form; the self-concat
  path did not. Pinned by `concat_amp_assign_wstring_width`, which asserts
  CONTENT rather than length so a half-copy cannot pass.

The prebuilt toolchains under `toolchains/` were rebuilt from this tree and each
was verified BY RUNNING IT, from the shipped tree rather than the build tree.
`gfxlib2` is NOT rebuilt for Linux (no `libxpm-dev` in the build environment);
that is sound because the only rtlib headers this work touched gained
DECLARATIONS ONLY, which cannot change gfxlib2's codegen.

### Not verified

- **The LLVM backend**, as before.
- `tests/afxnova_differential.bas` is Windows-only, needs AfxNova, and is NOT in
  the gate. See its header for the interop limitation that caps its sweep.
