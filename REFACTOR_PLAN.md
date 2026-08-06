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

### Still open in Phase 4

- **Readable debug names.** Every instantiation currently reports as `Box` to
  the debugger, so GDB sees N distinct types with one name. `symbGetDBGName`
  needs a per-instantiation readable form on the stabs path only — the mangled
  path must stay C-identifier-safe.
- **Scope placement** per deviation D1: instantiations land in the current
  namespace rather than by `symbLookupInternallyMangledSubtype`'s rules. Fine at
  module level, which is what the tests cover.
- **The chain's TEXT is not regression-tested.** The golden error harness agreed
  in the interview does not exist yet; `fail-error-in-body.bas` only asserts that
  compilation fails.
- **In-body line numbers** — see above.

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
