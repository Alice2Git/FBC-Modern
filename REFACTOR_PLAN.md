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
| 1 — scaffolding (semantic no-op) | **done** — gate green (see below) |
| 2 — body capture + structural pre-scan | **done** — gate green (see below) |
| 3 — parser save/restore + replay + minimal instantiation | **done** — gate green |
| 4 — type instantiation engine | **part 1 done** — mangling, recursion, depth limit |
| 5 — member protos + out-of-line bodies | **done** — gate green |
| 6 — generic procedures + inference | **done** — gate green |
| 7 — ctors/dtors/copy | **done** — gate green |
| 8 — operators + properties | **done** — gate green |
| 9 — inheritance/virtual *(cut line)* | **done** — gate green |
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

## Phase 1 — what landed

Pure scaffolding; nothing parses `(of T)` yet. Every addition is append-only.

| Change | Where |
| --- | --- |
| `FB_SYMBCLASS_GENERIC` (appended) + both class-indexed name tables extended | `symb.bi:112`, `symb.bas:2634`, `symb.bas:3181` |
| `FB_GENERICKIND`, `FB_GENTOK`, `FBS_GENERIC` + `gen` union member | `symb.bi` |
| `FB_SYMBATTRIB_GENERICSCOPE` `&h02000000`, `_GENERICINST` `&h04000000` (bits 25-26; `FB_SYMBSTATS` untouched — it is nearly full and already aliases values) | `symb.bi:172` |
| `symbIsGeneric` / `symbIsGenericInst` / `symbIsGenericScope` + `#dump` attrib rows | `symb.bi`, `symb.bas:2883` |
| 8 `FB_ERRMSG_*` appended before the sentinel, strings at matching ordinals | `error.bi:340`, `error.bas:437` |
| `LEX_TKCTX_CONTEXT_GENERIC` + `lexCtxIsInMemory()` predicate | `lex.bi:81` |
| `UPDATE_LINENUM` fires for GENERIC even while replaying from `deftext` | `lex.bas:37` |
| `lexGetLookAheadText( k, flags )` | `lex.bas`, `lex.bi` |
| `assert` bound in `lexPushCtx` | `lex.bas:43` |
| `-maxinstdepth <n>`, default `FB_DEFAULT_MAXINSTDEPTH` = 64 | `fb.bi`, `fb.bas`, `fbc.bas` |

`lexCtxIsInMemory()` replaces four `= LEX_TKCTX_CONTEXT_EVAL` tests that meant
"stream comes from DEFTEXT, never the file" — including the containment point in
`hReadChar` that stops a replay running off into the real source. Each
substitution is a provable no-op today because nothing constructs a GENERIC
context yet.

### Phase 1 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | 1688 passed, **0 failed** — identical to Phase 0 |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |
| cross-target mangling vs Phase 0 | **byte-identical** on win32, win64, linux-x86, linux-x86_64, dos |
| `FBSYMBOL` size | **320 bytes before and after** (measured, not inferred) |
| error numbering | unchanged — `error 14` still `error 14`; enum ↔ table verified aligned |

Delta vs Phase 0 (`1154415 / 1154404 / 11 / 2304`) is **+5 assertions / +4 tests**,
exactly the new `identifier-of.bas`. Failures unchanged at 11.

### Deferred out of Phase 1, deliberately

- The `-g` "Macro Expansion" marker in `lex.ctx->currline` (`lex.bas:250`) will
  read wrong for a generic replay. Cosmetic, `-g` only, unreachable until
  Phase 3 constructs a GENERIC context — fix it there.
- `lexPushCtx` got a debug `assert`, not a hard error. Making it return a status
  would change a shared function's contract and risk unbalancing existing
  `lexPopCtx` callers for no present gain; every caller already pre-checks its
  own recursion limit. The real protection is the Phase 4 instantiation-depth
  counter.

---

## Phase 4 (part 1) — what landed

Real template mangling, and generics that may refer to themselves.

### Itanium `I…E` type-argument mangling

Replaces the Phase 3 alias-suffix hack. `hMangleUdtId` now encodes an
instantiation's type arguments exactly as it already did for array descriptor
types, reading them back from the TYPEDEFs in the synthetic namespace — those
bindings *are* the arguments, in order. They are re-mangled in place rather than
stored as text, because Itanium abbreviation indices depend on the symbol being
mangled.

| tag | demangles to |
| --- | --- |
| `$3BoxIiE` | `Box<int>` |
| `$3BoxIdE` | `Box<double>` |
| `$3BoxI3BoxIiEE` | `Box<Box<int> >` |

Byte-identical across declaration orders, and source-case (`Box`, not `BOX`),
because the generic's source-case name is carried as the instantiation's ALIAS.

Two sub-bugs fixed on the way:

- `symbMangleType`'s STRUCT branch builds its **own** namespace chain, so it
  bypassed the `hMangleNamespace` skip and the synthetic namespace still leaked
  into nested names. It now skips `GENERICSCOPE` too.
- `hIsNested` appended a closing `E` with no matching `N` — `hMangleNamespace`
  emits nothing for a skipped namespace — producing malformed `3BoxIiEE`. It now
  looks through generic scopes.

### Self-referential generics

`type Node( of T ) : as Node( of T ) ptr nxt : end type` works, and the pointer
is usable, not merely declarable.

Two things had to line up, and the first was not what the spec anticipated:

1. **The instantiated struct must not carry the generic's name.**
   `symbStructBegin` publishes the name *before* the body is parsed, so naming it
   `Node` made the self-reference bind to the half-built struct and the
   `( of T )` was never consumed — `error 14: Expected identifier, found '('`.
   Instantiations now use an internal name (`__FBGENINST`) with the generic's
   name carried in the ALIAS, so `Node` resolves outward to the generic and
   re-enters the instantiation path.

2. **The forward-reference name must be up-cased.** `symbAddFwdRef` passes
   `FB_SYMBOPT_PRESERVECASE` and documents that it expects an already-up-cased
   id, while the struct created by the replay goes through normal up-casing.
   `symbCheckFwdRef` resolves by walking the same-name hash chain, so a
   lower-case forward reference never matched and the type stayed permanently
   incomplete — declarable, but `a.nxt->v` failed with `Incomplete type`.

### Depth limit

`-maxinstdepth` (default 64) now guards body replay, reporting
`FB_ERRMSG_INSTDEPTHTOODEEP`.

Nested type *arguments* deliberately do not accumulate depth — they are resolved
before the outer body is replayed — which matches RFC-0001: `Vector(of Vector(of
T))` is fine and terminates. Depth accrues only when one generic's *body* drives
another, so `fail-instdepth.bas` chains `A3 → B3 → C3` through their bodies.

Note the runaway case `Bad( of Bad( of T ) )` is caught by the forward-reference
mechanism before the counter is reached, so the depth limit is a backstop rather
than the primary guard. It was verified to fire rather than assumed.

### Phase 4 (part 1) gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — unchanged |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1698 passed, 0 failed** = 1696 + the 2 new tests |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |
| mangled names | `c++filt`-demanglable; identical across declaration orders |

### Phase 4 (part 2) — instantiation chain, sizeof

**Instantiation chain notes.** `errctx.instlocations`, mirroring
`paramlocations`, with `errPushInstLocation`/`errPopInstLocation`. Printed
outside `errReportEx` so they neither bump `errctx.cnt` (which drives `-maxerr`)
nor get eaten by the one-error-per-statement filter:

```
c3.bas(3) error 14: Expected identifier, found 'Wdiget'
  in instantiation of 'Box( of long )'
  required from c3.bas(8)
```

The site is captured *before* the replay swaps `env.inf`, or the chain would
point at the generic's own file. Two casing defects fixed: `env.inf.incfile` is
interned and may be up-cased, so the capture now keeps a source-case copy of the
file name; and the description uses the generic's ALIAS rather than the up-cased
`id.name`.

**`sizeof` / `len` over an instantiation.** These go through
`cTypeOrExpression`, which rejects a `(` after an identifier, so generics fell
through to the expression parser and were reported as undeclared variables.

### Line numbers inside a replayed body — tried, measured, reverted

Errors inside an instantiated body report the **generic's declaration line**,
not the offending line in the body.

Counting the replayed text's newlines was implemented and backed out.
Measurement across three fixtures gave `reported = start + 2*newlines + 1`
consistently — each newline counted by both the character-level sites in
`lexNextToken` and the token-level site in `lexSkipToken`. Separating the two
(char sites keep the original `deflen = 0` guard, token site relaxed for
GENERIC) did **not** fix it, so an EOL token is evidently consumed more than
once through the look-ahead ring. A confidently wrong line number *inside the
file* is worse than a coarser correct one, so the frozen behaviour stands and
the chain supplies the detail.

### A regression the targeted probes missed

The first `sizeof` fix called `lexGetLookAheadText( 2 )` for every `(` following
an identifier. That peek is not free — it drives the lexer two tokens further
than the path otherwise would, which disturbs macro expansion — and it broke
ordinary macro calls:

```
boolean_bop.bas(204) error 7: Expected ')', found '(' in 'check(  0, and,  0,  0 )'
```

Every generics probe passed against that compiler; only the full suite caught
it, on a file unrelated to generics. The peek is now guarded by a cheap symbol
test (`lexGetSymChain` is already attached, so it costs no extra look-ahead).

**Also worth remembering:** the failure surfaced as my summary filter printing
*nothing*, because the suite died before producing a summary. Empty output is
not a pass — check that the log contains a `Total` line.

### Phase 4 (part 2) gate

| Check | Result |
| --- | --- |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1700 passed, 0 failed** = 1698 + the 2 new tests |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |

### Golden error harness — built

`tests/errors/`, a sibling to `tests/warnings/`. Same design: compile each
`.bas` for five targets, capture the diagnostics into checked-in
`r/<target>/*.txt`, and the test is `git diff`. `make error-tests` runs it.

This is the net agreed in the interview. Before it, error text had **no**
regression coverage: `tests/warnings` only captures lines matching `" warning "`,
and the 1261 `COMPILE_ONLY_FAIL` log-tests assert nothing but `exit code == 1`.

**Verified to have teeth.** The chain wording was deliberately mutated from
`in instantiation of 'X'` to `while instantiating X`; the diff caught it on all
five targets, and the goldens went clean again on revert. A golden test that has
never been shown to fail is not evidence of anything.

**It immediately found two defects** on paths that had not been checked:
`Wrong number of type arguments, PAIR` and
`Generic used without a type argument list, BOX` were reporting up-cased names.
All diagnostics that name a generic now go through one `hGenericName` helper.

Goldens read as expectation-then-result, via `#print` markers in the source:

```
=== two levels: the chain shows both ===
	error 14: Expected identifier, found 'Gadgit'
  in instantiation of 'Inner( of long )'
  required from generic-inst-chain.bas(N)
  in instantiation of 'Outer( of long )'
  required from generic-inst-chain.bas(N)
```

**Documented limitation:** line numbers are normalised to `(N)`, so a diagnostic
pointing at the *wrong line* is not caught here — the same trade-off
`tests/warnings` makes, and the reason its goldens do not churn when unrelated
lines move. Asserted: error number, wording, ordering, chain structure.

Like `tests/warnings`, this does not return a non-zero exit code; it is a diff
test. Both golden diffs are now part of the per-phase gate.

### Still open in Phase 4

- **Readable debug names.** Every instantiation currently reports as `Box` to
  the debugger, so GDB sees N distinct types with one name. `symbGetDBGName`
  needs a per-instantiation readable form on the stabs path only — the mangled
  path must stay C-identifier-safe.
- **Scope placement** per deviation D1: instantiations land in the current
  namespace rather than by `symbLookupInternallyMangledSubtype`'s rules. Fine at
  module level, which is what the tests cover.
- **In-body line numbers** — see above.

---

## Phase 5 — what landed

Generic types have methods. `sub Stack( of T ).Push( ... ) ... end sub` is
captured once and replayed once per instantiation.

Prototypes needed no work at all — the whole `type ... end type` is replayed, so
`declare sub setv( byval x as T )` and the call type-check that follows it were
already working at the end of Phase 4. Everything here is the body half.

### How a body gets from source to code

Hooked in `cProcStmtBegin` right after the SUB/FUNCTION keyword, before
`cProcHeader`. Capture starts at the `.` **after** the `( of T )` clause, so
replay only pastes `<kind> __FBGENINST` in front. Teaching `cParentId` to accept
a type-argument list instead would buy nothing: inside an instantiation `T` is
already bound, so the header can only ever name the instantiation being replayed
into.

No depth counting in the capture, unlike the type-body capture: procedures
cannot nest in FreeBASIC and nothing else in a body produces `END SUB`. Counting
openings — what `hSkipCompound` does for error recovery — would be actively
wrong, because `dim cb as sub( )` mentions the keyword without opening a block.

Bodies are then **deferred**: an instantiation happens mid-statement
(`dim s as Stack( of long )`), and opening a procedure there is not something the
parser supports. Each (instantiation, body) pair is queued and drained at a
module-level statement boundary in `cProgram` — the position the body would have
occupied had the user written it by hand — plus once more at end of module.
Draining runs `cProgram()` over the replayed text rather than a hand-rolled
statement loop, so it cannot drift out of step with the real one.

Deferring is also what makes declaration order irrelevant, which was the point:
a body written **after** the first instantiation retro-queues for every
instantiation that already exists, and one written **before** is picked up by
instantiations made later. Both directions are covered by `member-procs.bas`.

Working: methods, `this`, fields, locals, `for`/`select` inside a body, a method
calling a sibling method, two type parameters, `string` and UDT arguments,
bodies in a separate `.bi`, a generic inside a namespace, and a member body that
instantiates *another* generic.

**Restriction, deliberate:** an out-of-line body must spell the type parameters
the way the declaration did. Binding is by name — the parameters are TYPEDEFs
under the declaration's names — so a renamed one would fail to resolve with a
confusing error. `FB_ERRMSG_TYPEPARAMMISMATCH` says so instead. Liftable later
by binding the body's own names too; nothing depends on it.

### Deviation D1 settled — instantiations are always module level

Phase 4 left instantiations in the *current* scope. That is unsurvivable once
generics have methods: `hDisallowNestedClasses` rejects a UDT with member
procedures below module level, because FreeBASIC has no nested procedures and
their bodies could never be implemented. A member body that instantiates another
generic is parsed inside a procedure, so **every generic with methods was
rejected** the moment one was used from inside another's body.

`genEnterGlobalScope`/`genLeaveGlobalScope` now move the parser and AST position
to module level and the current symbol/hash table to the global namespace's, for
the whole of an instantiation and each body replay.

This settles D1 the opposite way from the shipped precedent for array descriptor
types (`symbLookupInternallyMangledSubtype` goes local when inside a scope). The
cost is that a type argument naming a procedure-local UDT now outlives that
UDT's scope — the hazard the FBARRAY comment in `symb-var.bas` warns about. The
trade is deliberate: descriptor types have no methods, so the local branch costs
them nothing; for generics it costs everything.

**`symbNestBegin` is not usable for this.** Called on a namespace already in
scope — and the global one always is — it adds that namespace's hash table to
the nested-hash list a second time. The list is threaded through the hash table
itself, so the duplicate points at itself and every subsequent lookup spins
forever. The first attempt hung the compiler on the simplest test in the suite.

### Two mangling bugs, both pre-existing from Phase 4, both severe

Found by dumping `-r -gen gcc` output for the new method symbols, not by review.

**1. Every abbreviation-eligible type argument collapsed onto one name.**
`Box(of integer)`, `Box(of string)`, `Box(of MyUdt)` and `Box(of long ptr)` all
mangled as `_ZN3BoxIS_E...`, which `c++filt` reads back as `Box<Box>`. Four
distinct types, **one external symbol** — the linker keeps one body and the
others are silently discarded. Only `Box(of double)` differed, because plain
built-in types are not abbreviation candidates.

Cause: `hMangleNamespace` mangles a parent namespace **twice** — once into a
throwaway string purely to populate the abbreviation table (*"just doing
hAbbrevFind()/hAbbrevAdd() is not enough"*), then once for real. The warm-up
pass reached the `I…E` loop and registered each type argument, so the real pass
found them already present and emitted `S_` — a back-reference to something
never written. Fixed by suppressing abbreviation *lookup* inside the
template-argument list, so an argument is always spelled out.

**2. The template name did not occupy substitution slot 0.** Itanium counts
`<unscoped-template-name>` as a candidate in its own right, so in
`Box<FBSTRING>` a demangler numbers `Box` 0 and `FBSTRING` 1. fbc was not
reserving the slot, so every later reference came out one too low: for a method
taking two arguments of the parameter type, g++ writes
`_ZN3BoxI8FBSTRINGE4takeES0_S0_` and fbc wrote `S_S_`, demangling to
`Box<FBSTRING>::take(Box, Box)`. Fixed by reserving the slot.

Verified against `x86_64-w64-mingw32-g++` on the equivalent C++ template:
single-level instantiations are now **byte-identical** apart from the method
name, which fbc up-cases. Nested arguments diverge — fbc writes
`_ZN3BoxI3BoxIiEE4TAKEES1_` where g++ abbreviates the inner `Box` to `S_` —
because suppression applies inside the whole argument list. Both demangle to the
same type, the slot numbering still agrees with `c++filt`, and fbc generics are
not C++ templates to interoperate with. Recorded, not fixed.

**Not touched:** the array-descriptor branch just above has the same shape and
may carry the same latent defect. It is shipped behaviour with goldens pinning
it, and Phase 0 established that existing mangled names must not move. Worth
reporting upstream separately.

### The Phase 3 balance assert was asserting the wrong thing

`genRestoreState` asserted `parser.stmt.cnt`, described as the compound-statement
depth. It is not — it is a running count of statement separators that lives next
door in the same struct. It happened to hold because `cTypeDecl` never bumps it,
so the assert had never once tested what it claimed. Replaying a procedure body
runs `cProgram()`, which bumps it per line, and would have tripped it.

Now asserts `parser.stmt.stk.tos` (stack nodes are pooled, so equal depth means
the same pointer) and *copies* `cnt`.

### Test-name trap worth remembering

A type parameter named `K` cannot be used as a parameter type — `error 59:
Illegal specification`. This has nothing to do with generics: plain
`type K as long` plus `declare sub f( byval a as K )` is rejected identically.
Cost twenty minutes chasing a phantom two-type-parameter bug. `T`, `V`, `U`,
`W`, `Q`, `KK` and `ELEM` are all fine. Third time this project that an unlucky
test identifier has looked like a compiler regression (`base`, then `A`/`a`,
now `K`) — **check the control before concluding.**

### Tests added

| Path | Kind |
| --- | --- |
| `tests/generics/member-procs.bas` | `COMPILE_AND_RUN_OK` — 20 assertions over one and two type params, string/UDT/scalar args, control flow, sibling calls, both declaration orders, a nested instantiation, a namespace |
| `tests/generics/member-mangling/` | `MULTI_MODULE_OK` — link-time assertion on three exact Itanium names |
| `tests/generics/fail-memberproc-renamed-typeparam.bas` | `COMPILE_ONLY_FAIL` |
| `tests/generics/fail-memberproc-wrong-arity.bas` | `COMPILE_ONLY_FAIL` |
| `tests/generics/fail-memberproc-unbalanced.bas` | `COMPILE_ONLY_FAIL` |
| `tests/errors/generic-member-errors.bas` | golden diagnostics, 5 targets |

The mangling test **had to be two modules**, and the first single-module version
had no teeth at all. A `declare ... alias "…"` that is never referenced emits no
relocation and links happily against any mangling whatsoever — the Phase 0
lesson, met again in a new disguise. Taking the address forces resolution.
Matching signatures then make fbc report `Duplicated definition` against the real
method, and non-matching ones make gcc report a conflicting prototype since both
land in one C file; a second module avoids both. Proven by mutating each of the
three names in turn and confirming the link fails, on both backends.

### A second environmental failure set — `tests/cpp`, four tests

This run surfaced `cpp/call`, `cpp/call2`, `cpp/class` and `cpp/derived` failing,
which earlier phases had recorded as 0 failures. They are **not** a regression:

```
ld.exe: cannot find -lstdc++: No such file or directory
```

`libstdc++` is simply absent from `C:\dev\utils\mingw64`. Exactly the four tests
that `#inclib "stdc++"` fail; `cpp/bop` and `cpp/fastcall`, which do not, pass.
No change to fbc's mangler can produce a missing-library error.

Confirmed by controlled comparison rather than asserted — rebuilt the compiler
at `7052c70` with the Phase 5 sources stashed, ran the four by hand, got the
identical failures, restored and got them again. Same discipline as the Phase 0
baseline.

Why they appeared only now: this was the first run to invoke `make clean-tests`
from the **repository root**. Earlier phases followed the procedure at the top of
this file, which deletes `tests/**/*.o` but leaves other artifacts — and
`clean-tests` run from inside `tests/` silently does nothing (see Traps). Stale
artifacts had been masking these.

**Treat 4 `cpp` + 11 `threadcall_` as the environmental floor from here on.** A
fifteenth failure is a regression. Fixable by installing libstdc++ for this
mingw64, which is a toolchain change and not part of this work.

### Phase 5 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — unchanged from Phase 4 |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1701 passed, 4 failed** — the 4 being the pre-existing `cpp` set above |
| `tests/warnings` golden, 5 targets | clean — zero content change |
| `tests/errors` golden, 5 targets | additions only; no existing golden moved |

Unit-test figures are unchanged by design: every Phase 5 behaviour test is a
log-test, so none of them adds an fbcunit assertion.

The log-test count reconciles exactly: 1700 at Phase 4, **+5** new tests here,
**-4** for the `cpp` set that stale artifacts had been hiding, = 1701. All five
new tests are confirmed `RESULT=PASSED` individually, not merely absent from the
failure list.

### Still open

- **Readable debug names** (carried from Phase 4). Every instantiation still
  reports as `Box` to the debugger.
- **In-body line numbers** (carried from Phase 4). An error inside a replayed
  member body reports the body's `sub` line, not the offending line; the
  instantiation chain supplies the detail.
- **Modifiers before the kind keyword are dropped** — `private sub Box( of T ).f`
  loses the `private`, because capture starts at the generic's name and the
  replay re-enters `cProcStmtBegin` with no attributes. Checked rather than
  assumed: both `private sub Box( of T ).setv` and
  `const function Box( of T ).getv` compile and run correctly, because a method
  BODY takes its attributes from the prototype anyway (`cProcHeader`: *"for
  bodies it depends on the attributes inherited from the corresponding
  prototype"*). Not currently covered by a test.
- **A body for a member that was never declared** reports
  `Expected End-of-Line, found '.'`. Confirmed identical in plain FreeBASIC for
  `sub Box.nope()`, so pre-existing, not introduced here.

---

## Phase 6 — what landed

Generic procedures, called with explicit type arguments or with them inferred.

```freebasic
sub Swap2( of T )( byref a as T, byref b as T )
function Max( of T )( byval a as T, byval b as T ) as T

Swap2( of long )( x, y )      Swap2( x, y )
Max( of string )( "a", "b" )  Max( "a", "b" )
Deref( @v )                   '' T ptr binds T to the pointee
Pick( 7, 2.5 )                '' two parameters, independently inferred
```

### A generic procedure is a generic owning exactly one body

That framing is what kept this phase small: the whole Phase 5 deferred-queue
machinery carries generic procedures unchanged, including the retro-queueing
that makes declaration order irrelevant.

What is new is the split. The **header** is replayed eagerly, as a prototype,
the moment a call site needs a callable symbol; the **body** waits for a
statement boundary, because a call site is mid-expression and no procedure can
be opened there. That is exactly how FreeBASIC already treats a prototype and
its out-of-line body, so matching the two needed nothing new.

### Recognising the declaration — the backward-compatibility trap

Unlike `type Foo(`, the sequence `sub Foo(` is ordinary syntax, and `of` is not
a keyword and never will be. Checked against the compiler **before** writing the
detector, not after:

| probe | today |
| --- | --- |
| `sub foo( of as long )` | OK — and must stay OK |
| `sub foo( byval of as long )` | OK |
| `dim of as long` | OK |
| `sub of( byval x as long )` | OK |

One extra token settles it: a type parameter list always has an identifier after
`of`, while a parameter *named* `of` is followed by `as`, `,` or `)`. So
detection needs `(` + text `OF` + **token 3 is an identifier**.

The Phase 5 member-proc detector was also tightened to fire only for generic
*types*; otherwise re-declaring a generic procedure took the member-body path and
complained about a missing `.` instead of reporting the duplicate.

### Three bugs on the way, all found by probing

1. **The eager prototype could not be a `declare`.** Replaying one through
   `cProgram` fails with *"Illegal inside a NAMESPACE block"* whenever the call
   site is inside another procedure's body — `cProcDecl` gates on
   `cCompStmtIsAllowed( FB_CMPSTMT_MASK_DECL )` and the enclosing `FUNCTION`
   stack entry refuses it. Now calls `cProcHeader` directly, which has no such
   gate and is all that statement was wanted for.

2. **Mangling collapsed instantiations onto `_Z11__FBGENPROCv`.** Procedures do
   not go through `hMangleUdtId`, so they never got the `I…E` treatment. That
   emission is now a shared helper used by both, and for procedures it is emitted
   **whether or not C++ mangling is active**: under BASIC mangling a procedure's
   parameters are not encoded at all, so `MakeZero( of T )( ) as T` — type
   argument only in the return type — would otherwise give every instantiation
   the same name.

3. **`lexSkipToken` before the lexer was primed.** The kind keyword was never
   actually skipped, so `cProcHeader` tried to use `function` itself as the
   procedure's name, surfacing as a baffling "Duplicated definition" reported
   against the generic's own source line. Two dead-end theories (visibility
   attributes, then the body queue) died before a one-line repro made it obvious.
   **`lexGetToken( )` first.**

### Inference (RFC-0001 §5)

The pattern is matched over the **captured header tokens**, not over a parsed
signature. The plan proposed parsing the parameter list at declaration with each
type parameter bound to an opaque placeholder, and flagged that placeholders need
a nominal non-zero size or every incomplete-type check fires — *"the most likely
place for this plan to need a design change"*. Matching tokens needs no
placeholder to exist at all, and the positions the RFC admits (`T`, `T ptr`) are
precisely the ones trivial to recognise syntactically. Anything the matcher does
not understand falls through to a clean inference failure, which is what the RFC
prescribes for that case anyway. **The flagged risk never materialised because
that road was not taken.**

The ordering problem — `cProcArgList` wants the procedure before it parses
arguments, inference wants the argument types before the procedure exists — is
resolved by parsing the arguments once, keeping them, and handing them over
afterwards. `cProcArgList` already supports exactly that: it feeds pre-existing
`arg_list` entries through `astNewARG` before parsing anything itself.

**One deliberate normalisation.** A string *literal* has type `zstring`, which
cannot be a `byval` parameter, so `Max( "abc", "abd" )` inferred
`Max( of zstring )` and then failed deep inside the instantiated body with
"Illegal specification, at parameter 1". A literal's `zstring`/fixed-length type
is now normalised to `string`. This is **not** the implicit conversion §5 rules
out: that rule exists so inference never silently picks between two types the
author actually wrote, and it still does not. Here both arguments are literals
and `string` is the only type meant.

### The inference "bug" that was not one

`Max( v + v, v )` fails to infer. It looks like the same variable twice, and it
looked like a defect for two rounds of wrong guessing — first the mangling-only
type bits, then comparing rendered types instead of raw `(dtype, subtype)` pairs.
Neither changed anything, because neither was the cause.

One trace run settled it: the argument dtypes are **8 (`FB_DATATYPE_INTEGER`)**
and **11 (`FB_DATATYPE_LONG`)**. FreeBASIC promotes `long + long` to the native
integer, so the two arguments genuinely differ and §5 requires the rejection.
`Max( v, w )` and `Max( v + v, w + w )` work because each is self-consistent;
only the mix conflicts.

Both speculative fixes were **reverted** — each was an unjustified change
carrying a comment asserting an invented cause. The original comparison was
correct throughout. `fail-infer-mixed-promotion.bas` now pins the behaviour with
the measured dtypes recorded, so nobody re-derives this.

**Lesson, and it is the fourth of its kind here:** after `base`, `A`/`a`, `K` and
now integer promotion, an unexpected result is more often the test than the
compiler. Two theories cost more than one trace would have.

A second self-inflicted one: stripping the debug trace with `sed` deleted the
first line of a two-line `print` joined by `_`, leaving an orphaned continuation
that broke the build — and the harness in the same command then ran the **stale**
compiler and printed trace output. Twice this session a stale binary has produced
misleading results. Delete the artifact before every probe.

### Not implemented, deliberately

- `arr() as T` and nested `Vector( of T )` inference positions. Both fall
  through to a clean "specify them explicitly".
- Paren-less inferred statement calls (`Swap2 x, y`); an inferred call requires
  parentheses, since otherwise the argument list has no determinable end.
- Optional/default arguments and varargs on generic procedures are untested.
- Overload interaction (a viable non-generic beating a viable generic) — there is
  no overloading of generics in v1, so nothing exercises it yet.

### Phase 6 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | see commit |
| unit-tests, `GEN=gas64` | see commit |
| log-tests | see commit |
| `tests/warnings` golden, 5 targets | clean |
| `tests/errors` golden, 5 targets | clean |

Tests added: `generic-procs.bas` (explicit and inferred, `T ptr`, two type
parameters, return-type-only, generic calling generic, generic type method
calling a generic procedure) and `fail-infer-mixed-promotion.bas`.

---

## HANDOFF — read this first

### State of the tree

Branch `feat/generics`, **nothing pushed**. Phases 0-9 complete and gated.

Last commits:

```
ae8e086  tests: derive the astral surrogate expectations from the codepoint  (not generics)
8fd0874  Generics Phase 7: ctors, dtors and copy -- one real gap, not four
96d5066  Phase 6: generic procedures, with type-argument inference
e477cc5  Phase 5: generic types get methods
```

### What to do next

Phase 10 — the RFC-0002 iterator protocol. Expected to need **no compiler
change**: the contract is structural (`GetIterator()` returning a type with
`IsValid()` / `Value()` / `MoveNext()`), so it is a specification, a conformance
suite, and a page in `doc/`.

The cut line is behind us: everything Phases 10-12 need is in place.

Nothing is owed from Phase 9. The items still open are the ones carried since
Phase 4 (readable debug names, in-body line numbers), listed at the end of the
Phase 8 and Phase 9 sections.

**Before Phase 12 (containers), and before any `for each`, Vector, Dictionary,
Set or List work: get the author's approval first.**

### Gate protocol — do not skip

```
make compiler -j8 FBC="C:/dev/USTRING/fbc-master/bin/fbc.exe -i C:/dev/USTRING/fbc-master/inc"
cd tests && make unit-tests [GEN=gas64] ... && make log-tests ...
tests/warnings/test.sh  and  tests/errors/test.sh   then  git diff on r/
```

The repository root is **`fbc-master/`**, not `C:/dev/USTRING/` — `make` from the
outer directory reports "No rule to make target 'compiler'".

- **Environmental floor: 11 `threadcall_` + 4 `cpp`.** The 4 are missing
  `libstdc++` in this mingw64; proven by rebuilding at HEAD with changes stashed.
  A 16th failure is a regression.
- **Reconcile the log-test count, do not just read "no failures".**
  `passed + failed = total logs`, and passed should move by exactly the number of
  tests added. Baseline after Phase 9: **1711 passed / 4 failed / 1715 logs**.
  Count with `find tests -name "*.log" ! -name "log-tests-results*" ! -name
  "failed-*"` — the four `failed-<lang>.log` aggregates are not test logs and
  inflate a naive count by four.
- **A new test FILE in an existing directory is not picked up** without
  `make clean-tests` **from `fbc-master/`** — the generated list is cached.
  This silently hid two Phase 6 tests behind a green-looking gate.
- Check no log lacks a `RESULT=` line; a timed-out run leaves one truncated.
- Never run two `make log-tests` concurrently — they race and invent failures.

### Traps this project has actually hit

- `git` without `-C <abspath>` runs against the wrong repo. Always
  `git -C /c/dev/USTRING`.
- **`git stash push -- <file>` reverts the WHOLE file, not the hunk you had in
  mind.** Reached for to check whether one fix had teeth, it silently backed out
  the rest of the phase's work in that file too. To neutralise a single
  condition, edit it (`if( FALSE andalso ... )`), rebuild, observe, edit it back.
- Delete the old `.exe` before every probe. A stale binary has twice produced
  output that looked like a passing fix.
- **An unexpected result is more often the test than the compiler** — `base` is
  reserved, `A`/`a` collide case-insensitively, `K` cannot be a parameter type,
  `long + long` promotes to INTEGER, `str()` emits no leading space, a UDT used
  as a FOR variable needs a **default constructor** as well as its for/step/next
  trio, `x is T` requires a genuine DOWNCAST, and an override must itself be
  `virtual` to be overridden AGAIN a level down. Reserved so far: `base`, `Fix`,
  `Mid`. Nine false alarms now. Check the plain-FB control first — every one of
  these looked exactly like a compiler regression.
- An unreferenced `declare ... alias "..."` emits no relocation and links against
  any mangling at all. Take its address, and mutate the name to prove the test
  fails.
- Empty output is not a pass; look for the summary line.

---

## Phase 9 — what landed

Inheritance, `virtual`, `abstract` and RTTI. All three directions work:

| | |
| --- | --- |
| generic extends concrete | `type Sq( of T ) extends Shape` |
| concrete extends an instantiation | `type IntBox extends Box( of integer )` |
| generic extends generic | `type Der( of T ) extends Root( of T )` |

Also working: a base pinned to a fixed argument
(`type Pinned( of T ) extends Root( of integer )`), three levels of generic
hierarchy, `abstract` implemented per instantiation, and `extends` reached
through a `_` continuation.

Nothing about this phase was scoped as "build a feature". Every one of the four
bugs below was already sitting in the tree, and three of them produced **wrong
code with no diagnostic**.

### 1. The header clause was pushed onto its own line

Every inheriting generic failed at its first use with a syntax error reported
against the *generic's* declaration line.

Capture starts immediately after the `( of ... )` clause, so per cTypeDecl's
grammar the captured chain may still carry the rest of the HEADER —
`alias "..."`, `extends Base`, `field = n`. The replay joined the name and the
body with a newline unconditionally, so `extends Shape` landed on a line of its
own and read as a field declaration.

Phase 2 asserted this case worked (*"an `EXTENDS` or `ALIAS` clause on the header
is captured too and simply re-parsed at instantiation"*) and
`capture-boundary.bas` does declare such a generic — but never instantiates one,
because that file's whole point is that capture consumed exactly the body.
**The claim was never executed.**

The separator is now chosen by two tests, because either alone has a hole. The
line number settles it for ordinary source; a `_` continuation puts the clause on
a later line, and there the leading keyword settles it. A field actually *named*
`extends`/`alias`/`field` — legal in a TYPE without member procedures — is always
followed by `as`, which none of the three clauses ever is.

### 2. `union Foo( of T )` instantiated as a STRUCT

The replay text was hardcoded to `type ... end type`, so a generic union's fields
did not overlap. `sizeof( Pun( of double ) )` was 16 where the equivalent plain
union is 8, and writing one field did not disturb the other. Silent wrong code
since Phase 3.

Hidden by the same gap as bug 1: `capture-boundary.bas` covers the `union` form
at declaration and never instantiates it.

### 3. The instantiation was tagged too late

An instantiation used to get its ALIAS and `FB_SYMBATTRIB_GENERICINST` **after**
its body was parsed. That is fine for a plain generic and fatal for an
inheriting one: an `extends` clause makes `symbStructEnd` build RTTI, and
`hReBuildRtti` bakes the **mangled name into a string constant** — the one
`oop_istypeof` compares at run time — while `symbGetMangledName` caches its
result besides. So the struct kept the internal name:

```
struct $11__FBGENINST { ... };   '' Box( of integer )
struct $11__FBGENINST { ... };   '' Sq( of integer )
struct $11__FBGENINST { ... };   '' Sq( of double )
error: redefinition of struct or union 'struct $11__FBGENINST'
```

gcc rejected the file outright, which is the lucky case; the RTTI string would
have made `is` compare the wrong names.

Fixed by tagging at the only moment early enough: `hTypeAdd` calls
`genTagInstantiation` immediately after `symbStructBegin`. The generic's name is
held in `genctx2.pendalias`, **saved and restored around each replay** rather
than being a single slot — `extends Inner( of T )` instantiates Inner *before*
the outer struct is begun, so the inner replay would otherwise consume the
outer's tag.

A second defect surfaced alongside it. `symbAddFwdRef` publishes a forward
reference under the same `__FBGENINST` name so that a self-referential body
terminates, and it can still be on the hash chain — sometimes ahead of the real
struct — after `symbStructEnd`. Taking `chain_->sym` unconditionally therefore
picked the forward reference at random. The chain walk the Phase 8 gap-2 fix
added inside `hCacheLookup` is now a shared `hFindInstStruct` used at both sites.

### 4. gcc emitted a generic base after its generic derived

```
error: '_ZTSN4RootIu7INTEGEREE' undeclared here (not in a function)
```

`type Der( of T ) extends Root( of T )` creates Der's synthetic namespace first
and then instantiates Root while replaying Der's header, so **Root's symbols land
after Der's** in the global symbol table — and Der's RTTI initializer points at
Root's. Ordinary FreeBASIC cannot reach that position: a base must be declared
before it can be extended. That is exactly why `ir-hlc.bas`'s existing two-pass
scheme only forward-declares PUBLIC/EXTERN/COMMON.

The vtable and RTTI table of a **generic instantiation** are now declared in pass
1 (a C tentative definition) and defined in pass 2. Deliberately confined by
`symbIsGenericInst` on the owning UDT: every other program's emitted C is
byte-for-byte what it was, verified against a non-generic OOP control.

`gas64` was unaffected throughout — it does not care about declaration order.
Both backends are in the gate for exactly this reason.

### What the RTTI assertions actually assert

`oop_istypeof` compares mangled-name strings, so two instantiations that collide
on a name would answer `is` TRUE for each other. Every negative in
`inheritance.bas` is as load-bearing as the positive beside it:

```
*p is Sq( of integer )   ->  TRUE     '' p points at an Sq( of integer )
*p is Sq( of double )    ->  FALSE
```

and after `p = @sd` the two swap. That is a stronger check than a link-time
alias test, because it runs the comparison the way user code does.

Two instantiations of one generic are unrelated **statically** as well:
`*r is Der( of string )` where `r` is a `Root( of integer ) ptr` is
`error 298: Types have no hierarchical relation`, not a run-time FALSE.

### Two controls that were wrong before the compiler was

- `x is T` needs a genuine DOWNCAST. `dv is D` where `dv` is already a `D` is
  error 298 in plain FreeBASIC too. Three probes were written against that
  misunderstanding.
- **An override must itself be `virtual` to be overridden again.** A three-level
  hierarchy where the middle level writes plain `declare function nm( )`
  silently never dispatches to the leaf — in plain FreeBASIC exactly as in
  generics. Caught by the control, and the reason `Middle( of T ).nm` is
  declared `virtual` in the test.

Plus `Fix`, `Mid` and `Base` are all reserved. Three more identifier false
alarms, on top of `base`, `A`/`a` and `K`.

### Tests added

| Path | Kind |
| --- | --- |
| `tests/generics/inheritance.bas` | `COMPILE_AND_RUN_OK` — 44 assertions: all three inheritance directions, a pinned base argument, three levels, `abstract` per instantiation, `_` continuation, generic union layout, and RTTI positives *and* negatives in both directions |
| `tests/generics/fail-extends-uninstantiated.bas` | `COMPILE_ONLY_FAIL` |
| `tests/generics/fail-is-unrelated-instantiations.bas` | `COMPILE_ONLY_FAIL` |
| `tests/errors/generic-inherit-errors.bas` | golden diagnostics, 5 targets |

### Phase 9 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — unchanged since Phase 3 |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1711 passed / 4 failed / 1715 logs** — 1708 + 3 new; none missing a `RESULT=` |
| `tests/warnings` golden, 5 targets | clean — zero content change |
| `tests/errors` golden, 5 targets | additions only; no existing golden moved |
| emitted C for a non-generic OOP program | unchanged — the split declaration fires only for generic instantiations |

`inheritance.bas` was additionally run by hand under **both** backends, because
bug 4 is invisible to gas64.

### Not covered

- `extends` combined with a generic **procedure** or global operator — nothing
  connects the two, but it is untested.
- Virtual method bodies that themselves instantiate a further generic.
- `new` / `delete` on an instantiation (carried from Phase 7), which is where
  the deleting-destructor vtable slot would be exercised.
- The LLVM backend. Bug 4's fix is `ir-hlc.bas` only; `ir-llvm.bas` may carry
  the same ordering hazard and is not in the gate.

---

## Phase 8 — what landed

Operators and properties on generics. Probed before anything was written, per
the Phase 7 lesson, and most of it already worked:

| probe | before any change |
| --- | --- |
| `operator Arr( of T ).[]` | worked |
| `property Box( of T ).val` get and set | worked |
| `operator Box( of T ).cast` | worked |
| `operator Box( of T ).+=` | worked |
| global `operator +` on a CONCRETE instantiation | worked |

All of it rides the Phase 5 member-body path. Two gaps, and one mangling bug the
second gap exposed.

### Gap 2 — a self-reference in a prototype

```
declare operator next( byref e as Ctr( of T ) ) as integer
error 142: Invalid parameter type, it must be the same as the parent TYPE/CLASS
```

While a body is being replayed the instantiation cache holds a FORWARD
REFERENCE, so that a self-referential `Node( of T ) ptr` terminates. But once
`symbStructBegin` has published the real struct, a self-reference must get
THAT: some parameter checks compare symbol identity rather than the resolved
type, and reject the forward reference even though it prints identically. Plain
FreeBASIC never meets this — inside `type Ctr`, `Ctr` is already the real
symbol.

`hCacheLookup` now prefers a published struct and falls back to the forward
reference only while none exists. `recursive-generic.bas` still passes, which is
the test that depends on the fallback.

**Shown to have teeth** rather than assumed: with the preference disabled,
`member-operators.bas` fails with exactly the error above.

The case that needs it is the FOR/STEP/NEXT trio, which needs it three times
over. Phase 8 inherited that half as *unverified*, because the plain-FreeBASIC
control had failed with a different error — the control was simply wrong. A UDT
used as a FOR variable needs a **default constructor** as well as the three
operators. With that, both the plain and the generic loop work, and both are in
the test.

### Gap 1 — generic global operators

```freebasic
operator + ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as Box( of T )
```

Previously `error 147: Default types or suffixes are only valid in ...`, because
`genIsGenericProcDecl` requires an IDENTIFIER after the kind keyword and an
operator's name is a symbol token.

**The declaration was the easy half.** Detection is the same three-token test as
a generic procedure — `(`, text `OF`, token 3 an identifier — so
`operator +( of as Box, b as Box )`, which declares a *parameter* named `of`,
still compiles. It is checked **after** the member-body test, because
`operator Box( of T ).+=` matches the identical shape and is a member body; and
it refuses an identifier outright, so the two can never both claim the
statement. A self op is rejected here (`FB_ERRMSG_OPMUSTBEAMETHOD`) rather than
left to `cProcHeader`, which by then has no parent to complain about.

The generic owns one body, exactly as in Phase 6, and the whole capture /
eager-prototype / deferred-body path carries it unchanged. One difference: there
is no name to paste in front at replay time, so the **operator token itself
leads the captured header** and stands in for one. `cProcHeader`'s return value
is then the only handle on the result — a global operator is registered in
`symb.globOpOvlTb`, not in any hash table, so the `symbLookupAt( nsp,
"__FBGENPROC" )` the named path uses finds nothing.

`FB_SYMBATTRIB_GENERICINST` is deliberately **not** set on one. `hMangleProc`
takes the operator branch for the id, so the flag would only append an `I...E`
list, and it is not needed to keep instantiations apart: an operator living
inside the synthetic namespace is C++-mangled (`hDoCppMangling` returns TRUE for
anything outside the global namespace), so its parameter types are encoded, and
those are exactly what differ.

**The hard half is the use site.** There is nowhere in `x + y` to write explicit
type arguments, so inference is the only route — and a generic operator's
parameters are of the nested shape `G( of T )`, which Phase 6's inference
explicitly did not model. So the pattern matcher now inverts a nested position:
given an operand that is an instantiation of `G`, each of *its* type arguments
binds the corresponding type parameter. The instantiation's own arguments are
read back from the TYPEDEFs in its synthetic namespace — the same recovery
`hMangleTemplateArgs` does — and the generic it came from by walking the
instantiation cache, so `FBSYMBOL` does not grow.

The hook is `hDoGlobOpOverload` in `ast-node-bop.bas`: one choke point covering
every binary operator, rather than the thirteen `astNewBOP` call sites in
`parser-expr-binary.bas`. It is **silent** throughout. An operand matching
nothing is not an error — the same `AST_OP` may have ordinary overloads, or none
— so a failed inference instantiates nothing and the ordinary "Type mismatch" is
reported at the use site, which is exactly right for
`Box(of integer) + Box(of double)`. A golden case pins that *"Cannot infer type
arguments"* does **not** appear there.

Phase 6's named-procedure inference shares the new matcher, so `Vector( of T )`
positions now infer there too — the restriction recorded as "not implemented,
deliberately" in Phase 6 is lifted as a side effect.

**Documented limitation:** a nested position is matched against the operand's
generic **by name**. Two generics with the same name in different namespaces
could mis-bind. The failure mode is harmless — the wrong instantiation's
parameters then do not fit and overload resolution reports a type mismatch — and
the alternative, resolving the header token to a symbol at the use site, has the
same exposure from the other direction.

### A mangling off-by-one, found by comparing with g++

fbc emitted `_ZplR3BoxIdES2_` where `x86_64-w64-mingw32-g++` writes
`_ZplR3BoxIdES1_` for the equivalent C++ template. Not cosmetic: `c++filt`
cannot read the fbc form at all, because the index is past the end.

`hMangleNamespace` mangles a parent namespace **twice** — once into a throwaway
string purely to populate the abbreviation table, then once for real. Phase 4
taught the *emitting* pass to skip a generic scope, but the warm-up pass still
ran over it and registered a candidate. An abbreviation candidate that never
appears in the output leaves every later back-reference one index too high. The
warm-up now walks up to the nearest non-generic ancestor, which is the one that
does get emitted.

Measured, not inferred. Across every generics test plus the new ones, the fix
moves **only** instantiated generic procedures and global operators — the
symbols whose namespace *is* a generic scope — and moves all of them by exactly
−1. No type or member name moves, so Phase 0's "existing mangled names must not
move" holds. Names `c++filt` cannot parse dropped from 17 to 7, and the
single-level global operators are now byte-identical to g++.

The 7 that remain are pre-existing from Phase 6 and unrelated: `_Z3IncIiEi`,
`_Z8MakeZeroIdEv` and friends. Itanium encodes a function template's **return
type** immediately after the `I...E` list, and fbc emits only the parameters.
The names are still unique and stable across compilation units, which is all
Phase 6 claimed for them. Recorded, not fixed.

### Not implemented, deliberately

- The **prototype form** `declare operator + ( of T )( ... )`. Same as generic
  procedures in Phase 6: a generic's declaration is its body.
- Multi-token operator names (`[]`, `new[]`, `delete[]`). All of them are self
  ops, and a self op cannot be global, so one token of look-ahead is enough.
- **Unary** global operators. `genTryInstantiateGlobalOp` takes an argument
  count and the one-argument path is written, but only `hDoGlobOpOverload`
  (binary) calls it; the UOP site in `ast-node-uop.bas` is not hooked and
  nothing is tested.

### Tests added

| Path | Kind |
| --- | --- |
| `tests/generics/global-operators.bas` | `COMPILE_AND_RUN_OK` — three distinct instantiations of one operator, a concrete result type, a header mixing a nested and a bare position, two type parameters, an ordinary non-generic global operator alongside, cache re-use, chaining |
| `tests/generics/member-operators.bas` | `COMPILE_AND_RUN_OK` — `[]`, `cast`, get/set properties, a self op, and the for/step/next trio on two instantiations |
| `tests/generics/fail-globalop-selfop.bas` | `COMPILE_ONLY_FAIL` |
| `tests/generics/fail-globalop-conflict.bas` | `COMPILE_ONLY_FAIL` |
| `tests/generics/member-mangling/` | extended — two more exact Itanium names, for the global operator on two argument lists |
| `tests/errors/generic-operator-errors.bas` | golden diagnostics, 5 targets |

The two new mangling names were confirmed to have teeth the same way as the
Phase 5 ones: mutating `_ZplR3BoxIdES1_` to `...S2_` makes the link fail with an
undefined reference, on both backends.

### Phase 8 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — unchanged since Phase 3 |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1708 passed / 4 failed / 1712 logs** — 1704 + 4 new; none missing a `RESULT=` |
| `tests/warnings` golden, 5 targets | clean — zero content change |
| `tests/errors` golden, 5 targets | additions only; no existing golden moved |
| mangled names vs Phase 7 | only generic procedures and global operators move, all by −1; every type and member name byte-identical |

Unit-test figures are unchanged by design: every Phase 8 behaviour test is a
log-test, so none adds an fbcunit assertion. All four new logs were confirmed
`RESULT=PASSED` individually, not merely absent from the failure list.

### Still open

- **Readable debug names** (carried from Phase 4). Every instantiation still
  reports as `Box` to the debugger, so GDB sees N distinct types under one name.
- **In-body line numbers** (carried from Phase 4). An error inside a replayed
  body reports the body's opening line; the instantiation chain supplies the
  detail.
- **Function-template return types are not mangled** (from Phase 6, above).
- `new` / `delete` on an instantiation (carried from Phase 7).

---

## Phase 7 — what landed

Almost nothing, and that is the finding.

The plan said of `symbUdtDeclareDefaultMembers` / `symbUdtImplementDefaultMembers`:
*"should run per instantiation automatically via `symbStructEnd` — **verify,
don't assume**."* Verified. Three of the four things this phase was scoped to
build already worked, because Phase 5 routes **every** member body — constructor,
destructor, operator — through one capture-and-deferred-replay path, and
`symbStructEnd` does the rest per instantiation.

| probe | before any change |
| --- | --- |
| implicit ctor/dtor for a generic holding a `string` | worked |
| out-of-line `destructor Box( of T )( )` | worked |
| copy ctor + `operator Box( of T ).let` | worked — 2 copies, both invoked |
| `Box( of long )( 42 )` as a temporary | **failed** |

### The one real gap

Constructing a temporary. The expression parser dispatches a bare type name to
`cCtorCall` (`parser-expr-atom.bas`, the `FB_SYMBCLASS_STRUCT` arm) and had no
arm for a generic, so `Box( of long )( 42 )` reported *"Variable not declared,
Box"*.

Fixed by mirroring that arm: consume the type argument list, instantiate, then
hand the instantiated struct to the same `cCtorCall` path — rather than
inventing a parallel route. Needed one new predicate,
`genHasExplicitTypeArgsAfterId`, because the expression parser dispatches on the
symbol while the identifier is still current, whereas the Phase 6 call-site hook
asks the same question after consuming it.

### Counts balance, which is the actual test

```
scope1   ctor(x) + copy ctor + default ctor   ->  3 ctors, 2 copies, 3 dtors
scope2   Res( of Res( of string ) )           ->  5 ctors, 5 dtors
```

`ctors = dtors` throughout, and a temporary never bound to a variable is still
destroyed. That is the memcheck the plan asked for, written as assertions rather
than a separate run: a leak shows up as an imbalance. `ctor-dtor.bas` also covers
a generic with **no user-declared members at all**, where a `string` field alone
forces an implicit constructor and destructor per instantiation.

### Phase 7 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — unchanged |
| unit-tests, `GEN=gas64` | identical |
| log-tests | **1704 passed / 4 failed** — 1703 + 1 new test; 1704 + 4 = 1708 logs, none missing a RESULT |
| `tests/warnings` golden, 5 targets | clean |
| `tests/errors` golden, 5 targets | clean |

`ctor-dtor.log` confirmed `RESULT=PASSED` individually, not merely absent from
the failure list.

### Not covered

- `new` / `delete` on an instantiation.
- Assignment operators other than `let` (Phase 8 owns operators generally).
- A destructor that itself instantiates another generic.

---

## Phase 3 — what landed

`dim b as Box( of long )` compiles, runs, and works.  A generic's captured body
is replayed once per distinct type-argument list, with the type parameters
bound as TYPEDEFs in a synthetic namespace, and the result used as an ordinary
type.

A minimal instantiation was pulled forward from Phase 4, because Phase 3 as
planned ended with infrastructure nothing could exercise: the plan proposed a
`__FB_DEBUG__`-only self-test, but the suite runs a release compiler. Phase 4
still owns canonical-argument mangling, the depth limit, the instantiation
chain and debug names.

Working: scalar / string / UDT / nested arguments, two type parameters,
distinct argument lists as genuinely unrelated types, `-gen gcc` and
`-gen gas64`.

New in `parser-generic.bas`:
  `FB_PARSERSTATE`, `genSaveState`/`genRestoreState`
  `genReplayBegin`/`genReplayEnd`
  `cGenericTypeArgs`  — `( OF TypeRef, ... )` at a use site, recursive
  `genInstantiateType`— cache, synthetic namespace, typedef binding, replay
  explicit instantiation cache + `genInstCacheEnd`
Plus `errGetLastStmt`/`errSetLastStmt` (`error.bas`), the `FB_SYMBCLASS_GENERIC`
arm in `cSymbolType`, and the `GENERICSCOPE` skip in `hMangleNamespace`.

### Two bugs found by probing, not by review

1. **The instantiation cache never hit.** `symbAddNamespace` calls
   `symbNewSymbol` *without* `FB_SYMBOPT_PRESERVECASE`, so the stored name is
   up-cased, while the lookup used `preserve_case = TRUE`. Every mention of
   `Box( of long )` minted a fresh, incompatible type and `b2 = b` failed.
   Folding case would have been wrong anyway: the type-argument codes
   `symbMangleType` emits are case-significant, so distinct argument lists could
   collide. Replaced with an explicit per-generic cache.

2. **Mangling was not deterministic.** The synthetic namespace was named from a
   counter. `hMangleNamespace` skips `GENERICSCOPE`, but `symbMangleType`'s
   STRUCT branch builds its *own* namespace chain, so the namespace still leaks
   into a **nested** instantiation's name — making `Box( of Box( of long ) )`
   mangle as `…$GEN0$…` or `…$GEN1$…` depending on what preceded it. That breaks
   RFC-0001 §4 outright; separate compilation would not link. The name is now
   derived from the canonical key, verified byte-identical across declaration
   orders.

### Owed to Phase 4

- The synthetic namespace **still leaks** into nested mangled names. Deterministic
  and C-safe now, but the real fix is the Itanium `I…E` template-argument
  encoding, which removes the leak.
- `sizeof( Box( of long ) )` does not work: `sizeof` resolves through
  `cTypeOrExpression`, not the `cSymbolType` arm hooked here.
- Instantiations are placed in the *current* namespace rather than by
  `symbLookupInternallyMangledSubtype`'s scope rules. Fine at module level, which
  is what the tests cover; local-scope placement is Phase 4 (deviation D1).

### Phase 3 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — identical to Phases 1-2 |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1696 passed, 0 failed** = 1694 + the 2 new tests |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |
| nested-instantiation mangling | byte-identical across declaration orders (determinism fix verified) |

Unit-test figures are unchanged by design: every Phase 3 test is a log-test and
adds no assertion.

### Earlier notes from this phase

- `parser-generic.bas` — `FB_PARSERSTATE`, `genSaveState`/`genRestoreState`,
  `genReplayBegin`/`genReplayEnd`.
- `errGetLastStmt`/`errSetLastStmt` (`error.bas`) — `errctx` is module-private,
  and the one-error-per-statement filter keys off `laststmt`; without
  save/restore an error inside a replayed body can swallow the caller's next
  real error.

`genRestoreState` asserts `parser.stmt.cnt` is back where it started rather
than copying the stack, since that stack has its own push/pop discipline. A
replay that opened a compound statement and never closed it would otherwise
skew the caller and fail far from the cause.

`genReplayBegin` pre-checks `env.includerec` before `lexPushCtx` rather than
relying on the Phase 1 assert, matching what `fbIncludeFile` and the macro
evaluators already do, and returns FALSE without pushing so the caller must not
pop.

### Static-scratch re-entrancy audit (task complete)

Nine sites hold a `lexGetText()` pointer in a local. The result is better than
feared:

- `lexGetText` returns `@lex.ctx->head->text`, a pointer into the **per-context**
  token ring, and `lexPushCtx` moves `lex.ctx` to a different `ctxTB` slot
  (`lex.bi:153`). A replay therefore writes a different ring and **cannot
  clobber a pointer the caller is holding**. No change needed.
- **One real hazard:** for a `FB_DATATYPE_WCHAR` token, `lexGetText` narrows via
  `str()` into a single `static tmpstr` shared across *all* contexts
  (`lex.bas:2399`). A replay that lexes any wide token overwrites it under a
  caller holding that pointer. Unicode-source only.

### Known fidelity gap, same root cause

Capture stores `lexGetText()`, so a wide token is narrowed on the way in. A
generic body containing non-ASCII text in a unicode source file will not
round-trip. ASCII sources — the overwhelmingly common case — are exact. Fixing
it means capturing `textw` into `FB_GENTOK.textw` (the union member already
exists) and flattening to `DWSTRING`.

### Decision to surface before continuing

Phase 3 as planned ends with untestable infrastructure: the plan proposed a
`__FB_DEBUG__`-only self-test, but the suite runs a release compiler, so
nothing would actually exercise it. The intended fix is to pull a **minimal
instantiation** forward from Phase 4 — enough that `dim b as Box( of long )`
compiles and `sizeof` can be asserted — leaving canonical argument keys,
Itanium `I…E` mangling, the depth limit, the instantiation-chain notes and
debug names to Phase 4. `symbLookupInternallyMangledSubtype`
(`symb-proc.bas:1157`) supplies interning, scope placement and case-preserving
lookup in one call, exactly as `symbAddArrayDescriptorType` uses it.

---

## Phase 2 — what landed

`type|union Foo( of T, U )` parses. The body is captured verbatim into an
`FB_GENTOK` chain, block structure is validated at declaration time, and an
`FB_SYMBCLASS_GENERIC` symbol is registered. Referring to `Foo( of long )`
still errors — instantiation is Phase 4.

New: `parser-generic-capture.bas`
  `genCaptureTypeBody` — capture + structural pre-scan
  `hTypeParamList`     — `( OF ID (, ID)* )`, `of` matched by text
  `cGenericTypeDecl`   — creates the symbol, drives both
  `genFlattenTokens`   — replay-side; written but **not yet exercised**
  `genCaptureEnd`      — pool teardown, wired into fb.bas next to symbEnd

Hooked from `cTypeDecl` (`parser-decl-struct.bas`) after the name is read: a
`(` there is a syntax error today, and `of` is confirmed by one token of
look-ahead text.

Capture starts *after* the `(of ...)` clause and stops before the terminating
`END TYPE|UNION`, so an `EXTENDS` or `ALIAS` clause on the header is captured
too and simply re-parsed at instantiation.

### Bugs found by the tests, not by review

1. **Inner block ends were double-counted.** On a nested `end union` only the
   `end` was consumed, so the following `union` was re-examined on the next
   pass and counted as opening a new block. Every generic containing a nested
   union or enum failed. Both tokens are now consumed and recorded together.

2. **`symbCanDuplicate` did not know `FB_SYMBCLASS_GENERIC`.** Any class it
   does not recognise falls to `case else` → reject, so declaring a generic `A`
   made a later `dim a` fail with "Duplicated definition" — although `type A`
   plus `dim a` is legal today. A generic occupies a type name, so it now
   behaves exactly like `TYPEDEF`/`ENUM` in all four arms of that function.
   Easy to miss: it only appears when a generic's name collides
   case-insensitively with a later variable.

3. **`env.inf.name` is a reused fixed buffer, not a stable pointer.** Storing
   its address for the instantiation chain would have dangled as includes pop.
   Now stores `env.inf.incfile`, the interned copy `ast-node-proc.bas` already
   uses for debug info.

Two failures that looked like regressions but were **my test bugs**, both
confirmed against the Phase 1 compiler before drawing a conclusion: `type Base`
fails because `base` is a reserved word, and `type A` + `dim a` collides
because FB is case-insensitive. Worth the check — bug 2 above was a genuine
regression sitting right beside them.

### Phase 2 gate

| Check | Result |
| --- | --- |
| build | clean, zero warnings |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` — **identical to Phase 1** |
| unit-tests, `GEN=gas64` | `1154420 / 1154409 / 11 / 2308` — identical |
| log-tests | **1694 passed, 0 failed** = 1688 + the 6 new generics tests |
| `tests/warnings` golden, 5 targets | clean — 340 files regenerated, zero content change |

Unit-test figures are expected to be unchanged: every Phase 2 test is a
log-test, so none of them adds an assertion.

Tests added — `tests/generics/` (and `generics` added to `dirlist.mk`, which
needs a `make clean` to force the rescan):

- `capture-boundary.bas` — ten shapes, each followed by ordinary code that must
  still work. That is the assertion: the generic is never used, so the only
  thing under test is whether capture consumed exactly the body. Covers
  two type params, inner anonymous union, nested named enum, fields literally
  named `end` and `type`, `extends` on the header, `end type` inside a comment,
  `union` form, a `declare` prototype, and a generic inside a namespace.
- 5 x `COMPILE_ONLY_FAIL` — unbalanced body, unbalanced inner block, duplicate
  type parameter, empty `(of )`, non-identifier type parameter.

Deliberately **not** tested: that `Foo( of long )` errors. That is transient
Phase-2-only behaviour and would have to be deleted in Phase 4; enshrining it
as a test would be a trap for the next phase.

---

## Phase 1 — prep already verified (read-only, during the Phase 0 gate)

Both items the spec listed as *unverified assumptions* are now checked:

- **`FB_TK_OF` could be appended safely** — `FB_TOKENS` is *derived*
  (`fbint.bi:498`: `FB_TOKENS = FB_TK_THREADCALL - FB_TK_EOF`), not a literal, and
  only `kwdTb( 0 to FB_TOKENS-1 )` (`symb-keyword.bas:27`) uses it, as a *list*
  whose rows each carry their own id. **But see D4 below: we are not adding the
  token at all.**
- **`FB_SYMBCLASS_GENERIC` must extend two class-indexed tables.**
  `classnames()` (`symb.bas:2634`) and `classnamesPretty()` (`symb.bas:3181`) are
  bounded `FB_SYMBCLASS_VAR to FB_SYMBCLASS_NSIMPORT` and *are* indexed by
  `sym->class`. Appending the enum member means extending both bounds and adding
  a row to each — exactly as the comment at `symb.bi:111` warns.

---

## Deviation D4 — CORRECTED at the start of Phase 1

The spec proposed registering `of` as a shadowable `FB_TKCLASS_QUIRKWD` with an
identifier fallback. **That is wrong: QUIRKWDs cannot be used as variable
names**, so it would have broken the exact case RFC-0001 promises to preserve.

Measured:

| probe | result |
| --- | --- |
| `dim of as long = 7 : print of` | OK — and must stay OK |
| `dim len as long = 7` | `error 4: Duplicated definition` (LEN is a QUIRKWD) |
| `dim screen as long = 7` | `error 4: Duplicated definition` (SCREEN is a QUIRKWD) |

`symbLookup` hands back the keyword symbol, and `symbAddVar` then refuses the
name. "Shadowable" does not mean what the spec assumed.

**Corrected approach: `of` is never added to the keyword table.** It is purely
contextual, matched by identifier text with the existing house helper
`hMatchIdOrKw( "OF" )` (`lex.bas:2637`) — already used for `ONCE`, `LANG`,
`ACCESS`, `READ`, `WRITE`, `LOCK`, `LEN`, none of which are reserved words. It
accepts IDENTIFIER / QUIRKWD / KEYWORD class and compares `ucase( text )`.

This is strictly stronger than the original plan: `Foo( of T )` parses even
inside a scope where `of` is a declared variable, because only the token's
*text* is consulted. No new token, no `kwdTb` row, no `FB_TOKENS` change, and
nothing renumbered.

Phase 1 therefore adds `lexGetLookAheadText( k, flags )` (mirroring the existing
`lexGetLookAheadClass`) for the positions that need a text peek before
committing — `as Foo(of T)` and `Max(of T)(...)` — rather than a token id.

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
