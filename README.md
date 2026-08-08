<div align="center">

# FBC-Modern

**A FreeBASIC compiler with a portable Unicode string type, generics, an iterator protocol, `FOR EACH`, a standard container library, a modern date/time library, `defer`, and lambdas — built on fbc 1.20.0, with the existing language left untouched.**

[![Version](https://img.shields.io/badge/fbc-1.20.0-blue)](#)
[![Targets](https://img.shields.io/badge/targets-win64%20%7C%20win32%20%7C%20linux--x86__64-green)](#)
[![Tests](https://img.shields.io/badge/unit--tests-1%2C594%2C943%20assertions-brightgreen)](#tests)
[![Licence](https://img.shields.io/badge/licence-GPLv2%2B%20%2F%20LGPLv2.1%2B-lightgrey)](#-license)
[![Status](https://img.shields.io/badge/status-complete%2C%20offered%20upstream-orange)](#-project-goals)

[Features](#-key-features) · [Why](#-why-this-compiler) · [Examples](#-example-code) · [Quick start](#-quick-start) · [Ecosystem](#-ecosystem) · [Docs](#-documentation)

</div>

---

## Hero

FBC-Modern is a modified copy of the [FreeBASIC](https://www.freebasic.net/) compiler that adds language features, each built on the one before it: **generics**, a **structural iterator protocol**, **`FOR EACH`**, a **standard container library**, **`defer`** for scope-exit cleanup, and **lambdas** with optional capture — plus **`USTRING`**, a dynamic Unicode string type that is byte-identical on every target, and **`fb/chrono.bi`**, a date/time library that replaces the VB6 serial-`double` model with ticks, durations, clocks and ISO 8601.

It exists because FreeBASIC is a fast, direct, genuinely useful systems language with two long-standing gaps: there is no portable Unicode string, and there is no way to write a container that works for more than one element type without macros, `ANY PTR`, or copy-paste. Both gaps push real programs toward workarounds that lose type information — and both are fixable inside the existing language rather than beside it.

It is for **existing FreeBASIC users** who want their code to keep compiling unchanged, **systems programmers** who want typed containers without a runtime, **library authors** who have been writing the same `Vector` five times, and **compiler people** who want to see a template system implemented as parser replay rather than as a separate template language.

Everything here is **purely additive**. `STRING`, `ZSTRING`, `WSTRING`, `FOR`, and the existing `OPERATOR FOR/NEXT/STEP` protocol are unchanged; `each`, `in` and `defer` are not reserved words; the containers add nothing to the global namespace. If your program compiles with fbc 1.20.0, it compiles here — with one stated exception, a paren-less call in statement position to a sub named `defer`.

> **Scope, stated plainly.** This is fbc 1.20.0 with four features added and one caveat (see [Tests](#tests)). It is not a rewrite, not a new parser, and not a performance project. Where a capability does not exist, this README says so instead of implying it.

---

## ✨ Key Features

| Feature | What it is |
|---|---|
| **Generics** | `type Box( of T )` and `function Max( of T )( … )`. Bodies are captured as token chains and replayed through the real parser once per type-argument list — so code inside a generic is ordinary FreeBASIC and is diagnosed as such. Not a macro, not a separate template language. |
| **Iterator protocol** | A *structural* contract: a type is iterable if it has `GetIterator( )` returning something with `IsValid( )`, `Value( )` and `MoveNext( )`. No base class, no interface, no registration, nothing to inherit. |
| **`FOR EACH`** | Walks arrays (any `lbound`), var-len `STRING`, and any type satisfying the protocol. Lowered at compile time — no new AST node, no IR node, no backend change, no runtime call. |
| **String library** | 37 algorithms FreeBASIC does not ship — `Replace`, `Split`, `Join`, `Between`, the pad family, the character-set family — in namespace `FB`, working on **all four string types** from one call. Implemented in the runtime, but **nothing becomes a keyword**. |
| **`defer`** | `defer <statement>` runs on the way out of the enclosing **scope**, in reverse order, on **every** path — fallthrough, `exit`, `return`, `goto` out of nested scopes — and every iteration of a loop body. For the one-off `CloseHandle` that does not justify declaring a type. A **contextual keyword**: existing code using `defer` as a name keeps working. |
| **Lambdas** | `function( byval x as long ) as long … end function` in expression position. Non-capturing ones are **plain procedure pointers**, so every existing callback API — including `cdecl`/`stdcall` ones like `qsort` and Win32 — works unchanged. Capturing ones, `sub[ byref total ]( … )`, build a stack closure; every capture states `byval` or `byref` explicitly. |
| **`Optional` / `Result`** | `Optional( of T )` for a value that might not be there, `Result( of T, E )` for a value or the reason there isn't one. Pure library, no compiler support. Zero is a value; a default-constructed `Result` is a **failure**, so a forgotten assignment cannot read as success. |
| **Date/time** | `fb/chrono.bi` — `DateTime`, `LocalDate`, `LocalTime`, `Instant`, `TimeSpan`, `Clock`, `Stopwatch`, `CpuClock`, `TimeZoneInfo`. Immutable value types over `int64` ticks of 100 ns, years 1–9999. ISO 8601 / RFC 3339, custom patterns, OS-native offsets and DST, a monotonic clock. **Arithmetic never wraps**; out-of-range gives an `Invalid` sentinel. Ships **alongside** `datetime.bi`, which is unchanged; the two meet at `FromSerial` / `Serial`. |
| **Standard containers** | `Array`, `Map`, `Set`, `LinkedList` in namespace `FB`. Written in ordinary FreeBASIC on top of the three features above, with **zero compiler support** — so a better implementation by anybody else is on exactly equal footing. |
| **`USTRING`** | A dynamic Unicode string that is UTF-16 on *every* target, unlike `WSTRING` (2 bytes on Windows, 4 on Linux, 1 on DOS). A true intrinsic type in the compiler, not a library — `LEN` is O(1) and every string intrinsic works. |
| **Backwards compatibility** | Nothing existing changes. Verified by fbc's own suite — 1,154,412 assertions of it, plus this project's own suites on top — across four dialects, under **both** backends. |
| **Diagnostics** | New, specific messages for the new features — including the **instantiation chain** for an error inside a generic, and near-miss reporting that names the *missing member* rather than saying "not iterable". Diagnostics elsewhere are byte-identical to stock fbc. |
| **Unicode** | UTF-8 ↔ UTF-16 conversion fixed on every target (not locale-dependent), a generated BMP case-mapping table, and UTF-8 file output everywhere. |
| **Cross-platform** | Built, tested and shipped prebuilt for **win64**, **win32** and **linux-x86_64**. |
| **Backends** | All of fbc's backends carry the work: `gcc` (C emission), `gas64`, `gas` (x86 32-bit), and `llvm`. |
| **Prebuilt compilers** | Ready-to-run Windows and Linux installations are committed to the repository. No bootstrap required to try it. |

---

## 🤔 Why This Compiler?

Against **stock fbc 1.20.0**. Only rows where something actually changed:

| Stock FreeBASIC 1.20.0 | FBC-Modern |
|---|---|
| A container works for one element type, or uses macros / `ANY PTR` | `Array( of T )` — one implementation, fully type-checked per instantiation |
| Generic code via `#define`, diagnosed at the expansion with no scope | Generic bodies are real FreeBASIC, diagnosed at the body **plus** the instantiation chain that reached it |
| Every traversal is an index loop; `lbound` vs `0`, `ubound` vs `count-1` | `for each x in c` — over arrays, strings, and any user collection |
| Growable array means `redim preserve` per append — **O(n²)** over a loop | `Array.Push` is amortised **O(1)**; capacity doubles instead of reallocating on every append |
| No portable Unicode string: `WSTRING` is 2/4/1 bytes by platform, and fixed-length | `USTRING` — dynamic, UTF-16 everywhere, `LEN` O(1) |
| `WSTRING` append walks to the terminator: **O(n²)** | `USTRING` keeps its length in the descriptor: **O(1) amortised** — 400–900× faster at n=40,000 ([numbers](#performance-appending)) |
| `STRING` ↔ `WSTRING` conversion goes through the C locale — codepage- and machine-dependent | `STRING` ↔ `USTRING` is UTF-8 on every target, identical everywhere |
| A ustring-shaped file written on Windows is not what Linux writes | Files, pipes and non-Windows consoles get **UTF-8** on every platform |
| Dates are serial `double`s at second resolution — no duration type, no offset, no ISO 8601, no monotonic clock | `fb/chrono.bi` — 100 ns ticks, `TimeSpan`, UTC offsets and DST, ISO 8601 / RFC 3339, `Stopwatch` |
| `DateSerial( 2025, 13, 40 )` silently normalizes; a bad parse is indistinguishable from a valid one | Out-of-range construction returns `Invalid`; parsing is `TryParse` and **strict**; arithmetic never wraps |

Everything not in this table is deliberately identical, including diagnostics, code generation and compile times.

---

## 💻 Example Code

### Generics

```basic
type Box( of T )
    as T value
end type

type Pair( of K, V )
    as K k
    as V v
end type

dim b as Box( of long )
dim s as Box( of string )          '' a distinct, unrelated type
dim n as Box( of Box( of long ) )  '' nesting is fine

function Max( of T )( byval a as T, byval b as T ) as T
    if a > b then return a
    return b
end function

print Max( 3, 9 )                  '' T inferred from the arguments
print Max( of double )( 1.5, 2.5 ) '' or given explicitly
```

Out-of-line member bodies, constructors, operators and inheritance all work, and **declaration order does not matter**:

```basic
type Stack( of T )
    as T items( 0 to 15 )
    as integer count
    declare sub Push( byval x as T )
    declare operator [] ( byval i as integer ) byref as T
end type

sub Stack( of T ).Push( byval x as T )
    this.items( this.count ) = x
    this.count += 1
end sub

operator Stack( of T ).[] ( byval i as integer ) byref as T
    return this.items( i )
end operator
```

### Errors point at the instantiation that caused them

```
box.bas(13) error 14: Expected identifier, found 'Wdiget'
  in instantiation of 'Box( of long )'
  required from box.bas(18)
```

### `FOR EACH`

```basic
dim names(0 to 2) as string = { "ada", "grace", "edsger" }

for each n as string in names       '' a copy of each element
    print n
next

dim values(0 to 3) as long = { 1, 2, 3, 4 }

for each byref v as long in values  '' a reference — this modifies the array
    v *= 2
next
```

Any type with three members becomes iterable — no inheritance, no interface:

```basic
type MyIter
    declare function IsValid( ) as boolean
    declare function Value( ) byref as long
    declare sub MoveNext( )
end type

type MyList
    declare function GetIterator( ) as MyIter
end type

for each v in myList                '' just works
    print v
next
```

### Containers

```basic
#include once "containers.bi"
using FB

dim names as Array( of string )
names.Push( "ada" )
names.Push( "grace" )
names.Insert( 0, "hopper" )

dim ages as Map( of string, long )
ages[ "ada" ] = 36

dim seen as Set( of long )
seen.Add( 3 )

for each n in names
    print n, ages.Contains( n )
next
```

> **Three things to know.** `Array` indices are **zero-based**. `Map`'s indexer `m[ k ]` **inserts on a miss** — use `TryGet` or `Contains` to read. Copy and assignment are **deep** for all four containers; the language has no move constructor, so pass them `byref` where it matters.

### String library

```basic
#include once "fb/string.bi"
using FB

print Replace( "Hello World", "World", "Earth" )   '' Hello Earth
print Between( "log(42) end", "(", ")" )           '' 42
print PadLeft( "42", 6, "0" )                      '' 000042

dim parts as Array( of string ) = Split( "a,b,c" )
print parts.Count( ), Join( parts, " | " )         '' 3    a | b | c

'' the same calls take a ustring, a wstring or a zstring — the first
'' argument picks the family, and you never name it
dim as ustring u = "café noir"
print Replace( u, "noir", "au lait" )
```

`Join( Split( s, d ), d )` is `s` for every `s`. Positions are 1-based like
`INSTR`; `Split` never drops a field. Eleven deliberate differences from the
AfxNova originals, plus two AfxNova bugs found by the differential harness, are
listed in [docs/string/string.txt](docs/string/string.txt).

### Date and time

```basic
#include once "fb/chrono.bi"
using FB

dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 330 )
print d.ToIsoString( )                      '' 2025-03-04T14:30:05+05:30
print d.ToString( "dddd, dd MMMM yyyy" )    '' Tuesday, 04 March 2025

dim as DateTime bad = DateTime( 2025, 2, 30 )
print bad.IsValid                           '' false — not a normalized 2025-03-02

dim as TimeSpan age = Clock.UtcNow( ) - d.ToInstant( )
print age.TotalDays

dim as Stopwatch sw = Stopwatch.StartNew( )  '' monotonic; TIMER is not
'' … work …
print sw.ElapsedMilliseconds
```

> **Four things to know.** Values are **immutable** — `AddDays` returns a new one. Out-of-range construction and overflow give the `Invalid` sentinel rather than wrapping or erroring, and `Invalid = Invalid` is **false**, so test with `IsValid`. Parsing is strict `TryParse`, never a locale guess. `DateTime.FromSerial` / `.Serial` bridge to legacy `datetime.bi` doubles, so migration is per-function.

### `USTRING`

```basic
dim as ustring u = "héllo"          '' dynamic, grows on demand
u += " wörld"                       '' no fixed capacity to overflow

print len(u)                        '' 11 code units, O(1)
print ucase(u)                      '' HÉLLO WÖRLD
print mid(u, 7, 5)                  '' wörld

'' On Windows a ustring already IS UTF-16 — passing it to a wide API
'' is a pointer reinterpret with no conversion and no copy.
MessageBoxW( null, u, u, 0 )
```

---

## 🚀 Quick Start

Prebuilt compilers are committed to the repository. Clone it and run one.

> **Run `fbc` where it lives.** It derives its installation prefix from its own path, so the binary must stay beside its `bin/`, `include/` and `lib/` directories. Copying just the executable elsewhere gives `cannot open linker script file`.

### Windows

```bat
git clone https://github.com/PaulSquires/FBC-Modern.git
cd FBC-Modern

toolchains\fbc-modern-windows\fbc64.exe hello.bas
toolchains\fbc-modern-windows\fbc32.exe hello.bas
toolchains\fbc-modern-windows\fbc64.exe -target win32 hello.bas
```

The Windows tree is the standard FreeBASIC **standalone** layout: both compilers sit at the top level and share one `bin/` and one `inc/`, each picking the toolchain and runtime matching its target. Nothing to install and nothing to add to `PATH`.

### Linux (x86-64)

```bash
git clone https://github.com/PaulSquires/FBC-Modern.git
cd FBC-Modern

toolchains/fbc-modern-linux/bin/fbc hello.bas
./hello
```

A **native** Linux build, not a cross-compile — produced through fbc's own bootstrap path. The binary is committed with its executable bit set; if you extract the tree some other way, `chmod +x toolchains/fbc-modern-linux/bin/fbc`.

### macOS

No macOS build exists — this tree has never been built on darwin. Upstream FreeBASIC supports the target, so the path is likely short, but nothing here is verified. See [Building From Source](#-building-from-source) if you want to try it.

---

## 👋 Hello World

`hello.bas`:

```basic
#include once "containers.bi"
using FB

type Greeter( of T )
    as T name
    declare function Greet( ) as string
end type

function Greeter( of T ).Greet( ) as string
    return "hello, " & this.name
end function

dim people as Array( of string )
people.Push( "ada" )
people.Push( "grace" )

for each who in people
    dim g as Greeter( of string )
    g.name = who
    print g.Greet( )
next

dim as ustring u = "héllo, wörld"
print u, len( u )
```

Compile and run:

```bash
# Windows
toolchains\fbc-modern-windows\fbc64.exe hello.bas
hello.exe

# Linux
toolchains/fbc-modern-linux/bin/fbc hello.bas
./hello
```

Expected output:

```
hello, ada
hello, grace
héllo, wörld           12
```

That one file uses a generic type, an out-of-line generic member body, a container, `for each`, and a Unicode string — with no compiler flags and no build system.

---

## 🎯 Project Goals

1. **Close two real gaps in FreeBASIC** — no portable Unicode string, and no way to write a typed container once. Both are now closed.
2. **Preserve compatibility absolutely.** Existing programs compile unchanged; existing diagnostics are byte-identical; `each` and `in` stay usable as identifiers.
3. **Add to the language, not beside it.** Generics are parsed by the real parser. `FOR EACH` is a desugaring with no new AST or IR node. The containers are a library with no compiler privileges.
4. **Diagnostics that name the actual problem** — the missing iterator member, the instantiation that failed, the type argument that caused it.
5. **Be honest about limits.** Every known limitation is written down, measured, and shipped in the documentation rather than discovered by users.
6. **Offer the work upstream.** This exists to be reviewed and, if the FreeBASIC team wants it, merged — not to become a fork with its own ecosystem.

> **What this project is not aiming at:** a package manager, a language server, an optimizer, or faster builds. Those are worth having; they are not what this is.

---

## 🏗 Compiler Architecture

FBC-Modern uses fbc's existing pipeline. Only two stages gained anything.

| Stage | What happens | Changed? |
|---|---|---|
| **Lexer** | Tokens, dialect-gated keywords | `USTRING` added to the keyword table alongside `ZSTRING`/`WSTRING` |
| **Parser** | Single-pass recursive descent, building the AST directly | **Yes** — generic capture and replay, `FOR EACH` lowering |
| **Symbol / semantic** | `symb*` — types, overload resolution, mangling | **Yes** — instantiation cache, type-parameter binding, Itanium `I…E` mangling |
| **AST** | Expression and statement trees, constant folding | Unchanged — an instantiation is an ordinary UDT by the time the AST sees it |
| **IR / backends** | `gcc` (C), `gas64`, `gas` (x86), `llvm` | Unchanged for generics; `USTRING` emission added to all four |
| **Runtime** | libfb / libfbmt / libfbgfx | `USTRING` descriptors, codecs and I/O added; the date/time tick kernel, ISO and pattern engines, and the per-OS clock and zone backends added; nothing for generics |

<details>
<summary><b>How generics actually work</b> — four sentences, because nothing else in fbc looks like this</summary>

1. A generic's body is captured as a **token chain** at declaration and replayed through the **real parser** once per distinct type-argument list, with the type parameters bound as TYPEDEFs in a synthetic namespace. There is no textual substitution and no separate template AST.
2. Member bodies and generic-procedure bodies are **deferred** to the next module-level statement boundary, because an instantiation happens mid-statement and a procedure cannot be opened there. This is also what makes declaration order irrelevant.
3. Every instantiation is built **at module level**, whatever the parser was doing, because a UDT with member procedures is illegal below module level.
4. `for each` is a **desugaring** with two lowerings — an iterator walk for a user collection, an ordinary counter `FOR` for an array or string — so `for each` over an array emits exactly what the hand-written index loop emits.

Instantiations are Itanium-mangled: `$3BoxIiE` demangles to `Box<int>`. Two modules that both write `Box( of long )` mean the same type and link; each keeps a module-private copy, because PE/COFF offers no working COMDAT here (measured — `__attribute__((weak))` produces a weak *external* that silently breaks virtual dispatch).

Full detail: **[docs/generics/generics.txt](docs/generics/generics.txt)**.

</details>

---

## 🧩 Ecosystem

### Tiko Editor

**[Tiko](https://github.com/PaulSquires/tiko)** is a Scintilla-based FreeBASIC editor and IDE. It keeps its compilers in a `toolchains/` folder and lets you switch between them, so using FBC-Modern from Tiko is a copy and a menu selection — no configuration files to edit.

**1. Copy the toolchains.** Take the folders under this repository's `toolchains/` and drop them into Tiko's `toolchains/` folder:

```
FBC-Modern/toolchains/fbc-modern-windows/   →   tiko/toolchains/fbc-modern-windows/
FBC-Modern/toolchains/fbc-modern-linux/     →   tiko/toolchains/fbc-modern-linux/
```

Copy the folder whole. Each one is a complete, self-contained FreeBASIC installation — compiler, assembler, linker, headers and runtime — and `fbc` locates its own `bin/`, `inc/` and `lib/` relative to where the executable sits.

**2. Select it in Tiko.** Open **Options → Compiler Setup** and choose the toolchain you just added. Tiko's existing toolchains are left in place, so you can switch back at any time.

That is the whole setup. Build and run from Tiko as usual, and generics, `FOR EACH`, the containers and `USTRING` are available.

---

## 🔨 Building From Source

You do **not** need to build anything to use the compiler — see [Quick Start](#-quick-start). Build only if you are changing it.

**Dependencies**

| | |
|---|---|
| A FreeBASIC compiler to bootstrap with | fbc 1.10+ or the prebuilt compiler in this repository |
| GNU make | any recent version |
| A C toolchain | gcc/binutils — MinGW-w64 on Windows, the system toolchain on Linux |
| Optional | `libffi` (for `ThreadCall`), `libstdc++` (for the four `cpp` log-tests) |

**The makefile lives in `src/`, not at the repository root.** `make` from the root reports `No rule to make target 'compiler'`.

```bash
cd src
make compiler -j8 FBC="/path/to/fbc -i /path/to/FBC-Modern/src/inc"
```

The `-i` is required here: `fbc` does not auto-resolve `inc/` from `bin/` in this tree.

A full compiler rebuild is roughly **6 seconds at `-j8`** (146 modules). Touching any `.bi` rebuilds everything.

<details>
<summary><b>Full build, runtime included, and the test gate</b></summary>

```bash
cd src
make rtlib gfxlib2 compiler
```

The gate, in order — a phase is not done until all of it is green:

```bash
# unit tests, both backends
cd src/tests && make unit-tests            FBC="…/fbc.exe -i …/src/inc"
cd src/tests && make unit-tests GEN=gas64  FBC="…/fbc.exe -i …/src/inc"

# per-dialect compile-and-run tests
cd src/tests && make log-tests             FBC="…/fbc.exe -i …/src/inc -p /path/to/libstdc++"

# golden diagnostics, five targets each — regenerate, then git diff
cd src/tests/warnings && FBC="…/fbc.exe" bash ./test.sh
cd src/tests/errors   && FBC="…/fbc.exe" bash ./test.sh
```

Traps that have cost this project real time, all documented in [`tests/BASELINE.md`](tests/BASELINE.md):

- make tracks `.bas` → `.o` only, so a changed **compiler** leaves stale objects and the suite silently re-runs the previous binary. Force a rebuild.
- A new test **file** needs `make clean-tests` from `src/`; a new test **directory** needs `tests/dirlist.mk` *and* `make clean`.
- Never run two `make log-tests` concurrently — they race and invent failures.
- Reconcile `passed + failed = total logs`. "No failures" on its own proves nothing.

</details>

---

## Tests

fbc has four test targets. All four are run.

| Target | Scale | Result |
|---|---|---|
| `unit-tests` (win64, gcc) | fbc's suite plus this project's | **1,594,943 assertions — 11 failed** |
| `unit-tests` (win64, gas64) | same | **identical** |
| `log-tests` | 1,731 tests across `fb`, `fblite`, `qb`, `deprecated` | **1,731 passed, 0 failed** |
| `warning-tests` | 68 files × 5 targets | **0 diagnostic changes** |
| `error-tests` | golden diagnostics × 5 targets | **0 diagnostic changes** |

The 11 failures are all `fbc_tests.threads.threadcall_`, caused by `libffi` being absent in this build environment — **present in the baseline before any of this work**, and reproduced at `main` with the changes stashed.

`warning-tests` compiles for **dos, linux-x86, linux-x86_64, win32 and win64** and compares against committed reference output, so every diagnostic on every target is byte-identical to stock fbc except the ones deliberately added.

**This project's own suites**

| Suite | Covers |
|---|---|
| `src/tests/generics/` | 42 files — instantiation and identity, out-of-line members, operators and properties, generic procedures and inference, global operators, all three inheritance directions with `VIRTUAL`/`ABSTRACT`/RTTI, self-reference, mangling, deferral, multi-module linking, every container member and complexity claim, and 25 one-case diagnostic files |
| `src/tests/chrono/` | 8 fbcunit suites — ticks and components, `TimeSpan`, calendar arithmetic, clocks, ISO 8601, patterns, zones and locale, the `USTRING` overloads. Plus `tests/dt_core_test.c`, a standalone C harness: **23,304,597 checks**, including an exhaustive civil↔tick round trip over all 3,652,059 days in range |
| `tests/ustring_*.bas`, `tests/ustr_*.c` | 464 checks — the language surface, every declaration form, I/O and encodings, `DRAW STRING` compared pixel by pixel, the codecs against malformed input, and the wchar helpers at **all three wchar widths** |

Behaviour tests are additionally run under **both** backends by hand, and against the **prebuilt** compilers rather than the build tree — 17/17 on win64, win32 and linux-x86_64.

**Not verified**: the LLVM backend for generics (no LLVM toolchain on the build machine, and it is not in the gate), and the macOS, ARM, JS and DOS targets.

> **One caveat, stated plainly.** fbc's suite as shipped does not pass untouched. `tests/udt-wstring` and `tests/udt-zstring` each contain `#define ustring …` in 18 files, which becomes `error 4: Duplicated definition` once `USTRING` is a keyword. They are renamed to `uwstr_t` / `uzstr_t`; any upstream patch has to carry that 36-file rename.

### Performance: appending

`USTRING` moves 2 bytes per character where `STRING` moves 1, so equal *throughput* is parity. Best of three runs:

| Platform | STRING | USTRING | USTRING throughput |
|---|---|---|---|
| win64 | 10.71 ms (178 MB/s) | 16.01 ms | **238 MB/s** |
| win32 | 69.50 ms (27 MB/s) | 21.10 ms | **181 MB/s** |
| linux-x86_64 | 8.37 ms (228 MB/s) | 8.51 ms | **449 MB/s** |

Against `WSTRING` it is a different complexity class, not a tuning difference — a wstring has no length field, so every append walks to the terminator:

| Platform | WSTRING *n* → 2*n* | ratio | USTRING *n* → 2*n* | ratio |
|---|---|---|---|---|
| win64 | 82.45 → 339.56 ms | **4.12** | 0.21 → 0.31 ms | 1.43 |
| linux-x86_64 | 133.37 → 539.68 ms | **4.05** | 0.15 → 0.35 ms | 2.28 |

A ratio near 4 for doubled work is quadratic; near 2 is linear. At 40,000 appends `USTRING` is already **400–900× faster**, and the gap widens.

---

## 📚 Documentation

Everything below is in this repository. There is no documentation website.

| Document | What it covers |
|---|---|
| **[Generics reference](docs/generics/generics.txt)** | Declaration, instantiation, members, operators, generic procedures and inference, inheritance and RTTI, diagnostics, known limits |
| **[`FOR EACH`](docs/for_each/for-each.txt)** | Forms, what can be walked, how it lowers, backward compatibility, diagnostics |
| **[Iterator protocol](docs/for_each/iterator-protocol.txt)** | The RFC-0002 contract, and why the existing `OPERATOR FOR` protocol does not cover collections |
| **Standard library** — [Array](docs/array/array.txt) · [Map](docs/map/map.txt) · [Set](docs/set/set.txt) · [LinkedList](docs/linkedlist/linkedlist.txt) | Every member, its complexity, and the traps |
| **[String library](docs/string/string.txt)** | All 37 functions, their complexity, the rules that are easy to get wrong, and every divergence from AfxNova |
| **[Date/time reference](docs/datetime/datetime.txt)** | Every type and member, the tick model, the `Invalid` rules, exact vs calendar arithmetic, ISO 8601, the pattern language, clocks, zones and interop |
| **[Date/time overview](docs/datetime/README.md)** | What shipped, how to build and test it, what is and is not verified — and the index to the seven RFCs that specify it |
| **[Date/time migration guide](docs/datetime/migration.md)** | Every `datetime.bi` and AfxNova date member mapped to its `chrono` equivalent, and the `FromSerial` / `Serial` bridge |
| **[`USTRING` reference](docs/ustring/ustring.txt)** | The type, conversions, code units, I/O, the fixed-length form |
| **[Implementation notes](docs/ustring/implementation-notes.md)** | Design decisions **and the mistakes** — several bugs here compiled cleanly and produced plausible output |
| **[Test baseline & gate protocol](tests/BASELINE.md)** | How to reproduce every number on this page |
| **[FreeBASIC manual](https://www.freebasic.net/wiki/DocToc)** | The language itself, unchanged by this project. `src/doc/manual/` is a local mirror of that wiki and is regenerated from it rather than edited here. |
| **Compiler internals** | [The architecture section](#-compiler-architecture) above, and the *How it works* part of the generics reference. |

### Known limitations

Carried deliberately, all measured, none blocking. The full list with reasoning is in [docs/generics/generics.txt](docs/generics/generics.txt); the headline four:

- **No constraints on type parameters.** A member needing `=` on `T` makes the whole type unusable for a `T` without one — which is why `Array`'s `Sort`/`IndexOf`/`Contains` are free procedures.
- **`typeof( T )` does not see through a type parameter**, so a generic body cannot branch on what `T` is bound to. This is why the hash contract is an overloaded `HashOf`.
- **One copy of each instantiation per module.** Costs size, not correctness.
- **`CONST u AS USTRING`** is not supported — fbc's `CONST` accepts exactly one string type. `WSTRING` is rejected too.
- **No IANA tzdb in the date/time library.** Zones are OS-native only — UTC, the OS local zone, fixed offsets. No named zones, no historical rules, and `AssumeLocal` inside a DST fall-back hour takes the OS's answer. Leap seconds and non-Gregorian calendars are out of scope as well; each is argued in [docs/datetime/rationale.md](docs/datetime/rationale.md).

---

## 📄 License

This is a modified copy of the FreeBASIC compiler, so it carries FreeBASIC's licensing **unchanged**. Nothing is relicensed and no licence was chosen — it is inherited, and it is a split, because the work touches both halves.

| Part | Licence |
|---|---|
| The compiler — `src/src/compiler/`, and the binaries built from it | **GNU GPL v2 or later** ([COPYING.GPL-2.0](COPYING.GPL-2.0)) |
| The runtime and graphics libraries — `src/src/rtlib/`, `src/src/gfxlib2/` | **GNU LGPL v2.1 or later, with a static-linking exception** ([COPYING.LGPL-2.1](COPYING.LGPL-2.1)) |
| The container headers — `src/inc/fb/*.bi`, `src/inc/containers.bi` | **LGPL v2.1 or later, same exception** — they compile into your program, so they are runtime, not compiler |
| Documentation under `docs/` | **GNU FDL** |

The linking exception is what lets a program link the runtime statically without taking on the LGPL; it is quoted in full in [LICENSE](LICENSE).

**The prebuilt trees carry third-party components.** `toolchains/` redistributes the toolchain fbc invokes — GNU binutils and gcc under **GPLv3**, plus the MinGW-w64 runtime and import libraries under their own terms. They are unmodified redistributions.

---

<div align="center">

### FreeBASIC did not need replacing. It needed two gaps closed.

The containers in this repository are written in ordinary FreeBASIC, with no compiler privileges of any kind — which means **anything you write is on exactly equal footing**. Better containers, a macOS build, constraints on type parameters, or a bug report with a five-line repro: all of it moves this forward.

**[Open an issue](https://github.com/PaulSquires/FBC-Modern/issues) · [Read the generics doc](docs/generics/generics.txt) · [Run the gate](tests/BASELINE.md)**

*Offered for upstream discussion with the FreeBASIC team.*

</div>
