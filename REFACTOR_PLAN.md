# REFACTOR_PLAN.md — sketches S.2, S.5, S.4, S.3

**INTERNAL. Never published. Delete this file at merge time.**

Source: `C:\dev\fb-rfcs\rfcs\sketches.md`.
Approved plan: `C:\Users\TheDude\.claude\plans\swift-gathering-otter.md` (same content, Parts 1-4
below).

---

## HANDOFF — read this first

### STOP. The working tree is dirty, and none of it is this project's.

`main` is at `67911ad`, in sync with `origin/main`. But there are **~1,810 lines of uncommitted,
in-progress work** in the tree from two unrelated workstreams. Nothing below was written by the
session that produced this plan, and none of it has been gated. **Do not branch, do not stash, and
do not commit any of it without asking the author what state it is in.**

```
 M src/src/compiler/parser-generic.bas         A: generics namespace lookup
 M src/src/compiler/symb-namespace.bas         A
 M src/src/compiler/symb.bi                    A
?? src/tests/generics/namespace-qualified-inst.bas   A  (148 lines)

 M src/src/rtlib/fb_string.h                   B: the FB.* string library
 M src/src/rtlib/fb_ustring.h                  B
?? src/inc/fb/string.bi                        B  (236 lines)
?? src/src/rtlib/str_ops.c                     B  (295)
?? src/src/rtlib/str_ops_core.h                B  (272)
?? src/src/rtlib/ustr_ops.c                    B  (375)
?? src/tests/string/fbstr_search.bas           B  (484)
```

**Workstream A — a real generics bug, apparently fixed.** An instantiation is built in the global
namespace, so a generic declared inside a namespace loses every unqualified name it owns — a
sibling generic, a const. Every existing test and doc example writes `using FB` first, which put
the namespace on the search chain for an unrelated reason and hid it. So
`dim x as FB.Array( of string )` — the qualified form, the one a user writes before reaching for
`using` — did not compile. The fix adds refcounted `symbNamespaceSearchPush`/`Pop` in
`symb-namespace.bas` and threads the generic's declaring namespace through `genEnterGlobalScope`.
Read the comment at the top of `namespace-qualified-inst.bas`; it is written up properly.

**Workstream B — a new `FB.*` string library.** `Tally`, `StartsWith`, `EndsWith`, `Contains`,
`InstrChars`, `VerifySet`, `SpanOf`, declared three times each (STRING / WSTRING / USTRING, with
ZSTRING served by the STRING overload) and implemented in the runtime. This is **not** one of the
four sketches and is not in this plan.

**Both look finished and neither is verified here.** Before anything else:

```
cd src && make rtlib && make compiler -j8 FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc"
```

then the full gate (below). `src/tests/string/` is already in `tests/dirlist.mk`, so
`fbstr_search.bas` needs only `make clean-tests` **from `src/`** to be picked up — but B touches
`rtlib`, so `make rtlib` is required and the prebuilt toolchains would need rebuilding before B
could ship.

**Resolve A and B first — land them or park them — then start Phase 0.** Branching with this in
the tree carries it onto the new branch.

### Where this project actually stands

**Nothing is implemented. No branch exists.** The plan below was researched and approved; not a
line of it is written. Phase 0 is still to do.

The research behind it is worth not repeating — three parallel explorations of the scope-exit
machinery, the procedure/closure machinery and the container-library conventions. Their findings
are baked into Parts 2-4 with file paths and line numbers.

### What to do next

1. Resolve the dirty tree (above).
2. `git checkout -b feat/sketches` off `main`.
3. Reproduce the baseline yourself — do not quote the numbers in this file. Full gate, both
   backends, from a clean rebuild.
4. Phase 1: `src/inc/fb/optional.bi`. No compiler change, so it is the cheapest way to confirm the
   toolchain and the test harness are behaving before touching the parser.

### Decisions already taken — do not relitigate

Settled with the author in interview. Each one closed off alternatives that looked reasonable.

1. `Optional`/`Result` are **library-only**. No must-use diagnostic, no `?` propagation, no sum
   types. Ignoring a `Result` stays a convention. *(Rejected: sum types first — S.1 is Cost 4/5
   and a bigger project than all four of these.)*
2. Headers `fb/optional.bi`, `fb/result.bi`, namespace `FB`, **not** in `containers.bi` — they are
   not containers.
3. `HasValue`/`Value`/`ValueOr`; `IsOk`/`Value`/**`Failure`**. Not `Error_` as the sketch spells
   it — `Error` is reserved and the trailing underscore reads badly.
4. Construction by free procedure — `Some( x )`, `Ok( x )`, `Fail( e )`. Default-constructed
   Optional is empty, so `None` needs no spelling.
5. `Value( )` on empty **raises a runtime error** via the existing path. *(Rejected: documented
   precondition, and debug-only checking.)*
6. Optional is **not iterable**.
7. `defer` is **scope exit, reverse order, every path**, single statement, **contextual keyword**.
8. `goto` across a `defer` **reuses fbc's existing branch-crossing rule** — error where a ctor'd
   local errors, warning where it warns.
9. Lambdas **phased**: non-capturing, then capturing.
10. Closures live **on the stack**, in the enclosing frame. No heap, no allocation.
11. Capture lists are `sub[ byref total ]( args )` with an **explicit mode on every capture**.
12. `(` is taught to **call a closure struct**, so `f( 3 )` works for both kinds.
13. A capturing lambda reaches callbacks **through a generic parameter only**. *(Rejected: a
    static thunk — it breaks the moment there are two live closures, which is exactly the Ps\*
    control case that motivated the sketch.)*
14. **One branch, one commit per phase**, gate green each, `--no-ff` merge.
15. Tests **exhaustive** — every member, edge case and complexity claim.

### The two findings that make this affordable

Both came out of exploration and neither is obvious from the source.

**`defer` is cheap because cleanup is symbol-driven.** fbc has no list of scope-exit statements. It
derives cleanup from the scope's **symbol table**, walked `tail → prev`, and every entry must be a
variable with a destructor. There are exactly three consumption points, and `goto` out of three
nested scopes already runs all of them correctly. So a `defer` becomes a hidden symbol carrying an
AST tree, `symbGetVarHasDtor` returns TRUE for it, and `astBuildVarDtorCall` clones the tree
instead of building a destructor call. Reverse order, statement-number windowing and the crossing
diagnostics all fall out unchanged. See Part 2.

**Lambdas are affordable because the generics work already paid for the hard part.** Procedures can
only be opened at module level, and `astProcBegin`/`astProcEnd` are not a stack — which is why
generics defer bodies to the next module-level statement boundary. That machinery transfers whole:
token capture, parser re-entry, the global-scope hoist, the pending queue and its drain hook. What
does *not* transfer is listed in Part 3; the sharpest is that `hCaptureProcBody` stops at the first
`END SUB` because "procedures cannot nest in FreeBASIC", which a lambda inside a lambda breaks.

### Traps carried forward from the generics cycle

- **Build win32 every phase, not at the end.** `integer` is 64-bit on win64 and 32-bit on win32, so
  a type error against a `longint` parameter is invisible until you build 32-bit. That exact bug
  shipped and was found only when the prebuilts were rebuilt.
- **The prebuilt compilers under `toolchains/` are part of the deliverable.** They were shipped
  stale once. Any phase that changes the compiler invalidates them, and `src/inc/fb/*.bi` is
  duplicated into both toolchain trees.
- `git` without `-C <abspath>` runs against the wrong repo.
- **An unexpected result is more often the test than the compiler.** Twelve false alarms last
  cycle. Check the plain-FreeBASIC control first.
- Delete the old `.exe` before every probe.

---

## Gate protocol — do not skip

Full detail in `tests/BASELINE.md`. The makefile root is **`src/`**; `make` from the repository
root reports "No rule to make target 'compiler'".

```
cd src && make compiler -j8 FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc"
cd src/tests && make unit-tests            FBC="…"
cd src/tests && make unit-tests GEN=gas64  FBC="…"
cd src/tests && make log-tests             FBC="… -p C:/dev/utils/mingw64/lib"
cd src/tests/warnings && FBC="…" bash ./test.sh     # then git diff r/
cd src/tests/errors   && FBC="…" bash ./test.sh     # then git diff r/
```

Reference figures from the last green run on `main` — **reproduce them, do not trust them**:

| | |
| --- | --- |
| unit-tests, gcc | `1154420 / 1154409 / 11 / 2308` |
| unit-tests, gas64 | identical |
| log-tests | `1731 passed / 0 failed / 1731 logs` |
| warnings + errors | no diff, 5 targets each |

- **Environmental floor: 11 `threadcall_`.** A 12th is a regression. The 4 `cpp` log-test failures
  disappear when `-p C:/dev/utils/mingw64/lib` is passed.
- **Reconcile `passed + failed = total logs`.** "No failures" alone proves nothing. Count with
  `find tests -name "*.log" ! -name "log-tests-results*" ! -name "failed-*"`.
- A new test **file** needs `make clean-tests` from `src/`; a new **directory** needs
  `tests/dirlist.mk` and `make clean`.
- Never run two `make log-tests` concurrently.
- **Run behaviour tests under both backends by hand.** Three defects last cycle were visible to
  only one.
- **Golden error files hold one case each** — the compiler stops at the first error.

---

## Phases

| Phase | Content |
| --- | --- |
| 0 | Branch `feat/sketches` off `main`; reproduce the baseline |
| 1 | `fb/optional.bi` + exhaustive tests + `docs/optional/optional.txt` |
| 2 | `fb/result.bi` + exhaustive tests + `docs/result/result.txt` |
| 3 | `defer`: symbol representation, parsing, registration, fallthrough paths only |
| 4 | `defer`: all break paths — `exit`, `return`, `goto`, nested-scope exit |
| 5 | `defer`: diagnostics, golden error files, backward-compat tests, `docs/defer/defer.txt` |
| 6 | Lambdas: paren-balanced header capture, depth-counted body capture, synthesised proc, eager header replay |
| 7 | Lambdas: deferred body replay, procptr typing, context-driven overload selection, tests, docs |
| 8 | Closures: capture-list parsing, closure-struct synthesis, `__FBINVOKE` |
| 9 | Closures: the `(` call-site change, generic-parameter interop, the procptr diagnostic, tests |
| 10 | Multi-module tests, both backends, `README.md` / `src/changelog.txt` / `LICENSE`, **rebuild the prebuilts**, refresh the duplicated toolchain headers, merge |

---

## Part 1 — `Optional` and `Result` (no compiler change)

### Files

`src/inc/fb/optional.bi`, `src/inc/fb/result.bi`. Follow `src/inc/fb/array.bi` exactly: `''` header
comment naming the sketch and the idiom it replaces, ALL-CAPS mini-sections per design decision,
`#pragma once`, `namespace FB` un-indented, fields then `declare`s, **all bodies out-of-line**.

```freebasic
type Optional( of T )
    as T v
    as boolean has
    declare function HasValue( ) as boolean
    declare function Value( ) byref as T
    declare function ValueOr( byref dflt as T ) byref as T
    declare sub Clear( )
end type

function Some( of T )( byref v as T ) as Optional( of T )
```

`Result( of T, E )` mirrors it: `IsOk( )`, `Value( )`, `Failure( )`, free `Ok( )` / `Fail( )`.

### Three constraints that shape it

- **Eager member instantiation.** Every member of a generic is instantiated whether called or not,
  so a member needing `=` or `<` on `T` makes the whole type unusable for a `T` without one
  (`docs/generics/generics.txt:293`). **Neither type may have any member that constrains `T` or
  `E`** beyond default-construct, copy and destroy. Anything that does becomes a free procedure,
  as `Array`'s `Sort`/`IndexOf`/`Contains` did.
- **A `byref` return must refer to something.** `Value( )` on empty still returns a reference — use
  the function-`static` blank pattern from `src/inc/fb/linkedlist.bi:196`.
- **Inference reads parameter positions only.** `Some( 3 )` binds `T` to `INTEGER`, not `LONG`.
  Document it as `array.txt:96` documents `IndexOf( nums, 3L )`.

### Empty access

```freebasic
function Optional( of T ).Value( ) byref as T
    static as T blank
    if( this.has = FALSE ) then
        error( 5 )          '' Illegal function call, via fb_ErrorThrowEx
        return blank
    end if
    return this.v
end function
```

`error` is an existing quirk keyword (`symb-keyword.bas:189`) lowering to `fb_ErrorThrowEx`
(`rtl-error.bas:326`), so it is catchable by `on error` and reports a line under `-exx`.

### Tests

`src/tests/generics/container-optional.bas`, `container-result.bas`. Match `container-array.bas`:
`' TEST_MODE : COMPILE_AND_RUN_OK`, the standard `assert_` macro, a `Counted` fixture, sections in
`scope` blocks with banner comments, **destructor-balance assertions after `end scope`**. Target
~100 assertions each (the container files run 103-143).

Sections: empty state · construction by free procedure · `Value` on empty raises · `ValueOr` ·
assignment and reassignment · copy independence both directions · `T` = `string`, a UDT, a nested
`Array( of T )` · `Result` with distinct `T`/`E` and with `T` = `E` · destructor balance.

`fail-optional-*.bas` (one case per file) pinning that a `T` lacking `=` still instantiates — the
regression test for the no-constraining-members rule.

---

## Part 2 — `defer`

### What already exists

| Site | File | Role |
| --- | --- | --- |
| `astScopeDestroyVars` | `ast-node-scope.bas:600` | fallthrough off `end scope` |
| `astProcEnd`'s call | `ast-node-proc.bas:688` | fallthrough off `end sub`/`end function` |
| `hDestroyBlockLocals` | `ast-node-scope.bas:371` | **every** break path, windowed by statement number |

Non-fallthrough exits go through `astScopeBreak` (`ast-node-scope.bas:88`), which puts only the
`JMP` in the statement list and parks a `SCOPE_BREAK` node on the procedure's break list. Dtors are
spliced in before the `JMP` later by `astScopeUpdBreakList` (`:146`) → `hDelLocals` (`:433`), which
walks the `block.parent` chain outward until it reaches the block containing the target label.

### Design: a defer is a symbol

- New `FB_SYMBATTRIB_DEFER` plus a tree pointer on the var union in `symb.bi`.
- `symbGetVarHasDtor` (`symb-var.bas:869`) returns TRUE for it — all three sites then pick it up,
  in reverse order, inside the correct statement-number window (`symbGetVarStmt`).
- `astBuildVarDtorCall` (`ast-helper.bas:111`) gains one branch: for a defer symbol return
  `astCloneTree( tree )`. Cloning is required — the break-path splicer already builds a fresh tree
  per exit site. `astCloneTree` is `ast.bas:224`, 60 call sites.

Interleaving with real destructors falls out free: both live in one list in declaration order.

### Parsing

Contextual keyword on the FOR EACH precedent — `cForIsEach` (`parser-compound-for.bas:1193`),
matched by text via `hMatchIdOrKw` (`lex.bas:2696`). New `cDeferStmt` dispatched from `cQuirkStmt`
(`parser-quirk.bas:26`) only when the token text is `DEFER` **and** the next token is not `=`,
`as`, `(`, `.` or `:`. `astAddUnscoped` (`ast-node-proc.bas:376`) is the model for building a tree
without `astUpdate` flushing it into the statement list.

### Diagnostics

Appended after the FOR EACH block, which ends at error 346:

- `error 347: DEFER requires a statement`
- `error 348: DEFER is not allowed at module level`
- Crossing reuses `hCheckCrossing` (`ast-node-scope.bas:280`) **unchanged** — marking the defer
  symbol ctor-bearing makes `FB_ERRMSG_BRANCHCROSSINGDYNDATADEF` and
  `FB_WARNINGMSG_BRANCHCROSSINGLOCALVAR` fire as they do for a local with a constructor.

### Tests

`src/tests/generics/defer.bas`, ~60 assertions. Order proved by **appending to a string and
asserting the exact sequence**, not by eyeballing output: reverse order · fallthrough off
`end scope` and `end sub` · `exit sub`/`exit function`/`return` · `exit for`/`while`/`do` including
`exit for, for` · `goto` out of one and out of three nested scopes · a defer in a loop body running
per iteration · interleaving with a real destructor both ways · a defer reading a local declared
before it · defer in `if`/`select`/`with` arms · a defer never reached.

A backward-compatibility section asserting `defer` still works as a variable, a field and a sub
name. Golden error files in `src/tests/errors/` for the two new errors and the crossing pair.

---

## Part 3 — Lambdas, non-capturing

### The six obstacles, measured

1. `cDeclaration` (`parser-decl.bas:88`) intercepts a statement-initial `FUNCTION`/`SUB`, stepping
   aside only for `=`/`==`.
2. `cHighestPrecExpr` (`parser-expr-unary.bas:224`) has no `FB_TK_SUB`/`FB_TK_FUNCTION` arm; today
   the path ends `cQuirkFunction` → `cGfxFunct` → `NULL` → *"Expected expression"*.
3. `symbAddProc` (`symb-proc.bas:1100`) ignores `parser.scope` and asserts against
   `FB_SYMBATTRIB_LOCAL`.
4. `astProcBegin`/`astProcEnd` (`ast-node-proc.bas:445`, `:802`) are not a stack.
5. `hCaptureProcBody` (`parser-generic-capture.bas:673`) stops at the first `END SUB`.
6. `hCaptureProcHeader` (`:772`) is line-terminated, not paren-balanced.

### What transfers unchanged

`FB_GENTOK` + `hAddTokTo` + `genFlattenTokens`; `genSaveState`/`genRestoreState` +
`genReplayBegin`/`genReplayEnd`; `genEnterGlobalScope`/`genLeaveGlobalScope`
(`parser-generic.bas:178` — **note workstream A changes this signature**); the `FB_GENPENDING`
queue and `genDrainProcBodies`, drained at `parser-toplevel.bas:222` and `:239`; and the
eager-header/deferred-body split (`parser.bi:1187`). 3 and 4 are solved by these.

### Design

A new primary-expression arm in `cHighestPrecExpr`:

1. Capture the header **paren-balanced** (new `hCaptureLambdaHeader`), then the optional `as <type>`.
2. Capture the body **depth-counted**, copying `genCaptureTypeBody` (`:168`, helpers
   `hIsInnerUdtOpen` `:125`, `hIsBlockEnd` `:147`) rather than `hCaptureProcBody`'s first-`END`
   rule. This is what makes nested lambdas work.
3. Name via `symbUniqueLabel( )` — what `astProcAddStaticInstance` (`ast-node-proc.bas:1491`)
   already uses for a synthesised procedure.
4. Replay the header **eagerly** as `declare <kind> __FBLAMBDA_n( … )` at module level.
5. Queue the body on the existing pending list.
6. Return `astBuildProcAddrof( proc )` (`ast-helper.bas:713`) — `astNewVAR`
   (`ast-node-var.bas:24`) manufactures the procptr subtype via `symbAddProcPtrFromFunction`, so
   the result is type-identical to `@myproc` and passes `typeCalcMatch` (`symb-data.bas:616`).

Obstacle 1 is left alone: a statement-initial lambda is not a use case, and the existing error
stands. Document it.

### Tests

`src/tests/generics/lambda.bas`, ~50 assertions: assignment to an explicit procptr and to `var` ·
immediate call · passing as an argument · returning one · `sub` and `function` forms · zero/one/many
parameters · `byref` parameters and a `byref` return · in an array initialiser · two identical
signatures staying distinct · nested inside another lambda · inside a generic member body ·
overload selection via `parser.ctxsym` · `sizeof( f )` pointer-sized. Golden diagnostics for a
malformed header, an unterminated body, and a signature mismatch.

---

## Part 4 — Lambdas, capturing

### Design

`sub[ byref total ]( byref item as long ) … end sub` synthesises a **closure struct**, one field per
capture, hoisted to module level by `genEnterGlobalScope` — the deviation generics already
documents (`parser-generic.bas:161`), and the reason `hDisallowNestedClasses`
(`parser-decl-struct.bas:943`) does not reject its methods.

- `byval` captures are fields, copy-constructed where the lambda expression is evaluated.
- `byref` captures are pointer fields holding the address of the local.
- The body becomes a member `__FBINVOKE`, so captures resolve as `this.<name>`.
- The expression's value is a **stack temp in the enclosing scope**. No allocation.

### Making `f( 3 )` work

`cStrIdxOrMemberDeref` (`parser-expr-unary.bas:174`) today treats `(` as a call only for
`typeAddrOf( FB_DATATYPE_FUNCTION )`. Extend it: a `STRUCT` carrying a new `FB_SYMBATTRIB_CLOSURE`
rewrites to a member call on `__FBINVOKE`. Both lambda kinds are then called identically from
source.

### Interop, stated as a limit

A capturing closure has state; a procptr has nowhere to put it. Converting one is
`error 349: A capturing lambda cannot convert to a procedure pointer`. It reaches callbacks through
a generic parameter:

```freebasic
sub ForEach( of F )( byref a as Array( of long ), byref f as F )
    for each v in a : f( v ) : next
end sub
```

Non-capturing lambdas convert freely, so existing Win32-style callbacks keep working.

### Tests

`src/tests/generics/lambda-capture.bas`, ~60 assertions: `byval` is a snapshot · `byref` sees and
makes writes · mixed modes · capturing a `string`, a UDT with a destructor, an `Array( of T )` ·
destructor balance for `byval` captures · passed to and invoked through a generic parameter ·
stored and called twice · **two instances with independent state** (the case a static thunk gets
wrong) · nested capturing lambdas · `exit sub` from inside a body. Golden diagnostics for an
undeclared capture, a capture with no mode, and the procptr conversion error.

---

## Known limits to write down as they are created

- No constraints on type parameters, so `Optional`/`Result` may have no member that constrains `T`.
- A capturing lambda cannot become a procedure pointer.
- A closure holding a `byref` capture must not outlive its frame, and nothing diagnoses it — the
  same hazard as a pointer to a local, made visible by the explicit capture list.
- The closure type is hoisted to module level and outlives the scope that named it — deviation D1,
  already carried by generics.
- `defer` at module level is refused; there is no scope for it to exit.
