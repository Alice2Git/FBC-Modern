# REFACTOR_PLAN.md — generics for FreeBASIC (RFC-0001 … RFC-0004)

**INTERNAL. Never published. Delete this file at merge time.**

Branch: `feat/generics` off `main`. One commit per phase; a phase is not done
until its gate is green.

Full spec, decisions and architecture:
`C:\Users\TheDude\.claude\plans\zazzy-shimmying-codd.md`
Source RFCs: `C:\dev\fb-rfcs`

---

## Baseline (recorded 2026-08-06, on `main`)

Reproduced from scratch — full clean rebuild of the suite, not a stale binary:

```
1154412 assertions   1154401 passed   11 failed   2302 modules
```

Sole failing module: `fbc_tests.threads.threadcall_` (11/11), pre-existing,
caused by `-DDISABLE_FFI` in this environment. **A 12th failure is a regression.**

Log: `<scratchpad>/baseline-unit-main.log`

### Build/test invocation actually used here

`fbc` is not on PATH, and fbc does not auto-resolve `inc/` from `bin/` in this
tree, so **both** the compiler build and the test runs need an explicit `-i`:

```
make compiler -j8 FBC="C:/dev/USTRING/fbc-master/bin/fbc.exe -i C:/dev/USTRING/fbc-master/inc"
cd tests && make unit-tests FBC="C:/dev/USTRING/fbc-master/bin/fbc.exe -i C:/dev/USTRING/fbc-master/inc"
```

Full compiler rebuild: **~6 s at `-j8`** (146 modules). Touching any `.bi`
rebuilds everything.

Before every gate run, force a real test rebuild — make tracks `.bas` → `.o`
only, so a changed *compiler* leaves stale objects and the suite silently
re-runs the previous binary:

```
find tests -name "*.o" -delete
rm -f tests/fbc-tests.exe tests/unit-tests.inc tests/unit-tests-obj.lst
```

---

## Status

| Phase | State |
| --- | --- |
| 0 — pre-work: mangler + hUcase | **done** — gate green (see below) |
| 1 — scaffolding (semantic no-op) | not started |
| 2 — body capture + structural pre-scan | not started |
| 3 — parser save/restore + replay harness | not started |
| 4 — type instantiation engine | not started |
| 5 — member protos + out-of-line bodies | not started |
| 6 — generic procedures + inference | not started |
| 7 — ctors/dtors/copy | not started |
| 8 — operators + properties | not started |
| 9 — inheritance/virtual *(cut line)* | not started |
| 10 — RFC-0002 iterator protocol | not started |
| 11 — RFC-0003 `for each` | not started |
| 12 — RFC-0004 containers | not started |
| 13 — weak/COMDAT | not started |
| 14 — docs + merge | not started |

---

## Phase 0 — gate results (green)

| Check | Result |
| --- | --- |
| `make compiler -j8` | clean, ~6 s |
| unit-tests, gcc backend | `1154415 / 1154404 / 11 / 2304` |
| unit-tests, `GEN=gas64` | `1154415 / 1154404 / 11 / 2304` — identical |
| log-tests | 1688 passed, **0 failed** |
| `tests/namespace/cpp-abbrev` (new) | PASSED — fbc + `x86_64-w64-mingw32-g++` link together |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |

### Controlled comparison — do these changes move any test outcome?

`BASELINE.md`'s figure was captured against a `bin/fbc.exe` built at 05:49,
**six minutes before** `c90abfa` (which modified compiler sources). So a
straight diff against it would have conflated `c90abfa`'s changes with this
phase's. `fbc-master/bin/fbc.exe` is gitignored, so a stale binary can silently
outlive a source commit — worth remembering.

Closed by rebuilding the compiler from `c90abfa` with these fixes reverted
(`git checkout HEAD~1 -- fbc-master/src/compiler`) and re-running, **with the
same test files present in both runs**, so only the compiler differs:

| | assertions | passed | failed | tests |
| --- | --- | --- | --- | --- |
| `c90abfa`, fixes reverted | 1154415 | 1154404 | 11 | 2304 |
| `c90abfa` + these fixes | 1154415 | 1154404 | 11 | 2304 |

**Identical.** These changes alter no test outcome — as predicted by
"index ≤ 33 is byte-identical". The `+3 / +2` against `BASELINE.md` is entirely
the new `identifier-length.bas` (2 `TEST` blocks, 3 assertions), present in both
runs, which also shows `c90abfa` perturbed nothing.

Note: `BASELINE.md` recorded its numbers under the default (gcc) backend only,
so there is no `main` baseline for gas64. It needed none here — the gas64
failure *set* is identical (only `threadcall_`) and its totals match the gcc run
exactly, so nothing is unexplained.

---

## Phase 1 — prep already verified (read-only, during the Phase 0 gate)

Both items the spec listed as *unverified assumptions* are now checked:

- **`FB_TK_OF` can be appended safely.** `FB_TOKENS` is *derived*
  (`fbint.bi:498`: `FB_TOKENS = FB_TK_THREADCALL - FB_TK_EOF`), not a literal, so
  appending after `FB_TK_THREADCALL` also requires updating that expression to
  reference the new last token. Only **one** array is dimensioned by it —
  `kwdTb( 0 to FB_TOKENS-1 )` (`symb-keyword.bas:27`) — and it is a *list* whose
  rows each carry their own token id, never indexed by token id. Nothing is
  renumbered.
- **`FB_SYMBCLASS_GENERIC` must extend two class-indexed tables.**
  `classnames()` (`symb.bas:2634`) and `classnamesPretty()` (`symb.bas:3181`) are
  bounded `FB_SYMBCLASS_VAR to FB_SYMBCLASS_NSIMPORT` and *are* indexed by
  `sym->class`. Appending the enum member means extending both bounds and adding
  a row to each — exactly as the comment at `symb.bi:111` warns.

---

## Phase 0 — findings

### 0a. `hAbbrevGet()` substitution encoding — FIXED

`symb-mangling.bas:315`. Itanium `<substitution> ::= S <seq-id> _`, where
`<seq-id>` is `(index - 1)` in base 36 over `0-9A-Z`. fbc switched to a broken
2-digit form at index 34 and emitted `chr( idx \ 33 )` — a **raw control byte**.

Verified, old vs new, on the same source:

| substitution index | old | new | g++ |
| --- | --- | --- | --- |
| 32 | `SV_` | `SV_` | `SV_` |
| 34 | `S<0x01>0_` | `SX_` | `SX_` |
| 38 | `S<0x01>4_` | `S11_` | `S11_` |

- **Index ≤ 33 is byte-identical to before**, so no existing mangled name moves.
- New output matches **g++** exactly, and `c++filt` demangles it; the old output
  c++filt could not parse at all.
- More severe than "undemanglable": under `-gen gcc` the control byte lands in a
  C identifier and **gcc rejects the generated file** —
  `error: stray '\1' in program`. It simply never triggered because nothing in
  the existing suite reaches index 34. Nested generic type arguments will.

Test: `tests/namespace/cpp-abbrev/` (`MULTI_MODULE_OK`). A C++ interop test —
g++ mangles the definitions, fbc must agree or the link fails. Chosen over a
hard-coded `alias "_ZN…"` string because of finding 0c below. Confirmed to fail
on the pre-fix compiler and pass after.

### 0b. `hUcase()` unbounded write — FIXED (hardening)

`hlp.bas:169` copied until NUL with no bound; `symbLookup` (`symb.bas:1137`) and
`symbLookupAt` (`symb.bas:1249`) both hand it a
`static as zstring * FB_MAXNAMELEN+1` (129 bytes). Added an optional `dstchars`
limit (0 = unbounded, preserving every other caller) and passed `FB_MAXNAMELEN`
at those two sites.

**Honest scope: no source-level reproducer exists today.** The lexer truncates
identifiers at `FB_MAXNAMELEN` (`lex.bas:488`) before `symbLookup` ever sees
them, and internal mangled ids go through `FB_SYMBOPT_PRESERVECASE` /
`preserve_case = TRUE`, which skip `hUcase` entirely. Old and new compilers
behave identically on a 200-char identifier (warn + truncate). This is
defence-in-depth for the long internal ids Phase 4 will create.

Audited the other four call sites — all size their destination from
`len( src )` (`xallocate`, `ZstrAllocate`, `poolNewItem`) or are in-place. Safe.

Test: `tests/dim/identifier-length.bas` pins the boundary from both sides
(ids differing after char 128 are the same symbol; before 128, distinct), so
changing the lexer limit or the `hUcase` bound without the other is caught.

### 0c. `alias "…"` silently truncates at 128 chars — NOT FIXED, reported

`cAliasAttribute` (`parser-proc.bas:14`) assigns the literal into
`static as zstring * FB_MAXNAMELEN+1`, which truncates rather than overflowing.
Safe, but lossy and silent: a user cannot hand-write an `alias` for any mangled
name longer than 128 characters.

Deliberately left alone — it is a third, separate bug, needs its own decision
(truncate vs. error vs. raise the limit), and **does not block generics**:
instantiation aliases are set internally via `symbStructBegin`, not through this
parser path. Raise upstream separately.

---

## Traps worth remembering

- `clean-tests` is a **root** makefile target. `make clean-tests` from inside
  `tests/` silently does nothing and you re-run the previous binary.
- FB's `ASSERT()` expands to nothing without `-g`. A link-time mangling test
  written with `ASSERT( f(...) = x )` emits **no call at all** and passes even
  when mangling is broken. Cost me one wrong test; use unconditional calls.
- A test file without a `' TEST_MODE :` tag is silently never run.
- Adding a new test *directory* needs `tests/dirlist.mk` **and** a `make clean`
  to force the rescan.
