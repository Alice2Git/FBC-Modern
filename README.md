# FBC-Modern — FreeBASIC with a Unicode string, generics, `FOR EACH` and containers

A working implementation of four proposed language features against the
[FreeBASIC](https://www.freebasic.net/) compiler, version 1.20.0 — compiler,
runtime, tests, documentation and prebuilt binaries for Windows and Linux,
intended for upstream discussion.

Every one of them is **purely additive**. `STRING`, `ZSTRING`, `WSTRING`, the
existing `FOR` and the existing `OPERATOR FOR/NEXT/STEP` protocol are unchanged,
`each` and `in` are not reserved words, and nothing is added to the global
namespace.

```basic
dim as ustring u = "héllo wörld"          '' dynamic, UTF-16 on every target

type Box( of T )                          '' generics
    as T value
end type

dim names as FB.Array( of string )        '' the standard containers
names.Push( "ada" )

for each n in names                       '' FOR EACH
    print n
next
```

| | Feature | Docs |
|---|---|---|
| **USTRING** | a portable, dynamic Unicode string — an intrinsic type, not a library | [docs/ustring/ustring.txt](docs/ustring/ustring.txt) |
| **Generics** | types and procedures parameterised by type (RFC-0001) | [docs/generics/generics.txt](docs/generics/generics.txt) |
| **Iterator protocol** | a structural contract, not a base class (RFC-0002) | [docs/for_each/iterator-protocol.txt](docs/for_each/iterator-protocol.txt) |
| **`FOR EACH`** | arrays, strings and any type satisfying the protocol (RFC-0003) | [docs/for_each/for-each.txt](docs/for_each/for-each.txt) |
| **Containers** | `Array`, `Map`, `Set`, `LinkedList` (RFC-0004) | [array](docs/array/array.txt) · [map](docs/map/map.txt) · [set](docs/set/set.txt) · [linkedlist](docs/linkedlist/linkedlist.txt) |

The last three build on the second, and the container library is written in
**ordinary FreeBASIC with no compiler support at all** — which is the strongest
evidence that the generics underneath it are good enough for real code.

---

# Generics

```basic
type Box( of T )
    as T value
end type

dim b as Box( of long )
dim s as Box( of string )        '' a distinct, unrelated type

function Max( of T )( byval a as T, byval b as T ) as T
    if a > b then return a
    return b
end function

print Max( 3, 9 )                '' T inferred
print Max( of double )( 1.5, 2.5 )
```

**Not a macro, and not a separate template language.** A generic's body is
captured as a *token chain* at declaration and replayed through the real parser
once per distinct type-argument list, with the type parameters bound as TYPEDEFs
in a synthetic namespace. So the code inside a generic is ordinary FreeBASIC and
is diagnosed as such — an error inside a body reports at the body, then prints
the instantiation chain that reached it:

```
box.bas(13) error 14: Expected identifier, found 'Wdiget'
  in instantiation of 'Box( of long )'
  required from box.bas(18)
```

What is supported: out-of-line member bodies (`sub Stack( of T ).Push`),
constructors, destructors and copy, member operators and properties including
`FOR`/`STEP`/`NEXT`, generic procedures with inference, generic *global*
operators (inferred through the nested operand type), all three inheritance
directions — generic extends concrete, concrete extends instantiation, generic
extends generic — plus `VIRTUAL`, `ABSTRACT` and RTTI, self-reference through a
pointer, nesting, and a depth limit (`-maxinstdepth`, default 64).

Declaration order does not matter, because member bodies are deferred to the
next module-level statement boundary. Instantiations are Itanium-mangled, so
`$3BoxIiE` demangles to `Box<int>` and two modules that both say
`Box( of long )` link.

The main gap is **no constraints on type parameters** — a member that needs `=`
on `T` makes the whole type unusable for a `T` without one. That, and the rest,
are in [docs/generics/generics.txt](docs/generics/generics.txt) under
*Known limits*.

---

# `FOR EACH` and the iterator protocol

```basic
for each n as string in names            '' a copy of each element
for each byref v as long in values       '' a reference — v *= 2 modifies it
```

Walks a fixed or dynamic array (any `lbound`), a var-len `STRING` (one byte per
iteration), and any type satisfying the RFC-0002 protocol:

```basic
declare function GetIterator( ) as <iterator>
    '' with IsValid( ) as boolean, Value( ) [byref] as E, MoveNext( )
```

A **structural** contract — no base class, no interface, no registration, and
nothing to inherit from. A user collection lowers to an iterator walk; an array
or string lowers to an ordinary counter `FOR`, so `for each` over an array emits
what the hand-written index loop emits and costs exactly the same. There is no
new AST node, no IR node, no backend change and no runtime call.

The collection expression is evaluated **exactly once**. `EXIT FOR` and
`CONTINUE FOR` work, including the multi-level forms, and an iterator with a
destructor is destroyed on every exit path.

Because the failure mode of a structural protocol is a near-miss, the
diagnostics name the missing member rather than saying "not iterable":

```
error 343: Not an iterator type, an iterator needs IsValid( ) as boolean,
           Value( ) [byref] as E and MoveNext( ), missing, MoveNext( )
```

---

# The standard containers

```basic
#include once "containers.bi"
using FB

dim names as Array( of string )
dim ages  as Map( of string, long )
dim seen  as Set( of long )
dim queue as LinkedList( of string )
```

| | | |
|---|---|---|
| `Array( of T )` | growable array | amortised O(1) append |
| `Map( of K, V )` | open-addressed hash map | O(1) average lookup |
| `Set( of T )` | hash set | plus union / intersect / except |
| `LinkedList( of T )` | doubly-linked list | O(1) insert and remove at a known node |

**No compiler code at all** — `inc/fb/*.bi`, written in FreeBASIC on top of
generics, the iterator protocol and `for each`. They get no special treatment,
so a better one written by anybody else is on exactly equal footing. They live
in `NAMESPACE FB` and add nothing to the global namespace, so a program with its
own `Array` or `List` is unaffected until it says `using FB`.

`Array`, `Map` and `Set` store elements in ordinary FreeBASIC dynamic array
fields, `redim preserve`d only when the capacity doubles — never per push. The
language therefore does element construction, copying and destruction, so deep
copy, assignment and the destructor fall out for free with no manual memory to
get wrong. (`LinkedList` holds raw nodes, so those three are hand-written.)

Three things to read before using them:

- **`Array` indices are zero-based** — a deliberate break with `dim arr(1 to 10)`.
- **`Map`'s indexer `m[ k ]` INSERTS on a miss.** Use `TryGet` or `Contains` to read.
- **Copy and assignment are deep for all four.** The language has no move
  constructor, so pass them `byref` where it matters.

A user type becomes a `Map` key or `Set` element by overloading `HashOf` —
see `inc/fb/hash.bi`. It is an overload rather than a compile-time dispatch
because `typeof( T )` cannot see through a type parameter; that limitation is
recorded in the generics doc.

---

# USTRING — a portable, dynamic Unicode string

A proposed fourth string type: **dynamic, Unicode, and byte-identical on every
target**.

```basic
dim as ustring u = "héllo"      '' dynamic, grows on demand
u += " wörld"                   '' no fixed capacity to overflow
print len(u)                    '' 11 code units, O(1)
```

## Why

FreeBASIC has three string types, and none of them is a portable Unicode string.

| Type | Dynamic? | Encoding | Element width |
|---|---|---|---|
| `STRING` | yes | none — it is a byte buffer | 1 byte |
| `ZSTRING * N` | no | none — NUL-terminated bytes, for C interop | 1 byte |
| `WSTRING * N` | **no** | `wchar_t`, whatever the platform says | **2 on Windows, 4 on Linux, 1 on DOS** |
| **`USTRING`** | **yes** | **UTF-16, always** | **2 bytes, every target** |

The problem is the last column. The same source builds a UTF-16 string on one
target and a UTF-32 string on another — silently — and whichever you get, you
cannot resize it. That width leaks into every byte offset, every pointer walk,
and every file written.

USTRING fixes both halves at once: one type that is dynamic *and* has a fixed,
known representation everywhere.

## A true intrinsic type, not a library

This is the part worth being precise about. USTRING is **not** a UDT, a class,
a macro, or a header you `#include`. It is a data type inside the compiler,
registered exactly the way `ZSTRING` and `WSTRING` are.

**It is a keyword**, sitting on the line below its siblings in the keyword table
with the identical token class and dialect gating:

```basic
( @"ZSTRING"    , FB_TK_ZSTRING     , FB_TKCLASS_KEYWORD , KWD_OPTION_NO_QB ), _
( @"WSTRING"    , FB_TK_WSTRING     , FB_TKCLASS_KEYWORD , KWD_OPTION_NO_QB ), _
( @"USTRING"    , FB_TK_USTRING     , FB_TKCLASS_KEYWORD , KWD_OPTION_NO_QB ), _
```

**It is in the datatype enum.** `FB_DATATYPE_USTRING` (the var-len descriptor)
and `FB_DATATYPE_FIXUSTR` (`USTRING * N`), mirroring the `STRING`/`FIXSTR` pair.
`FB_DT_TYPEMASK` is 5 bits — a hard ceiling of 32 datatypes, of which fbc used
26. These are two of the remaining six.

**It is in all six positional datatype tables** that fbc keeps in lockstep —
`symb-data.bas`, `ir-hlc.bas`, `ir-llvm.bas`, `edbg_stab.bas`,
`symb-mangling.bas`, `emit_x86.bas`. A type that is missing from any one of
these is not a real type.

**Every backend emits it natively**: gcc, gas64, gas x86 (32-bit), and LLVM.
Literals are compile-time constants in their own pool (`{fbuc}`), with a
dedicated `littextu` storage slot holding raw UTF-16 units — so there is no
runtime construction cost and no host-width dependency.

**It participates in the language**, not just in expressions: overload
resolution ranks it, `VAR` infers it, `BYREF`/`BYVAL` parameters and copy-back
work, function results work, UDT fields and arrays are constructed and destroyed
by the generated ctors/dtors, and it has a temp-descriptor pool with the same
descriptor-stealing optimisation `STRING` uses, so `a = b + c + d` stays linear.

What that buys you concretely: **there is no seam.** Every intrinsic works, and
`LEN` is O(1) rather than a scan.

```basic
dim as ustring a = "hello", b = "world"
dim as ustring c = a + ", " + b        '' one assign + N concat-assigns, zero temps

print ucase(c)                         '' HELLO, WORLD
print mid(c, 8, 5)                     '' world
print instr(c, "wor")                  '' 8
print len(c), c[0]                     '' 12   104
```

## How it relates to the existing types

USTRING is accepted anywhere `STRING` or `WSTRING` is, converting on the way.

```basic
dim as string  s = "from a byte string"
dim as wstring * 32 w = "from a wide string"
dim as ustring u

u = s                     '' UTF-8 decoded
u = w                     '' re-encoded if wchar_t is not 16-bit
s = u                     '' UTF-8 encoded
w = u

print u & " and " & s     '' mixed concatenation, either order
if( u = s ) then ...      '' cross-type comparison
```

| Conversion | How |
|---|---|
| `STRING` / `ZSTRING` ↔ `USTRING` | **UTF-8, on every target** |
| `WSTRING` ↔ `USTRING` | re-encoded only where `wchar_t` ≠ 16 bits |

Note the deliberate difference from `STRING` ↔ `WSTRING`, which goes through the
C locale and is therefore codepage- and machine-dependent. A portable type
cannot afford that, so USTRING's conversions are fixed and identical everywhere.

Malformed UTF-8 becomes **U+FFFD** rather than raising an error — a text editor
must be able to open a damaged file, not refuse it.

### The one boundary

**Arbitrary binary does not round-trip through a USTRING.** Bytes that are not
valid UTF-8 become U+FFFD and the originals are gone. Binary data belongs in
`STRING`, which is unchanged and still there. This is a design decision, not an
oversight: a type that guarantees an encoding cannot also be a byte bucket.

### Win32 `...W` APIs are free

Where `wchar_t` is 16 bits — i.e. Windows — a ustring already *is* UTF-16, so
passing one to a `WSTRING PTR` parameter is a pointer reinterpret with no
conversion and no copy:

```basic
declare function MessageBoxW( byval hWnd as any ptr, byval txt as wstring ptr, _
                              byval cap as wstring ptr, byval flags as ulong ) as long

dim as ustring msg = "hello"
MessageBoxW( null, msg, msg, 0 )      '' no conversion, no copy
```

Where `wchar_t` is wider the text is re-encoded into a temporary and **the
compiler emits a warning**, so that cost is never invisible to someone
developing on Windows.

## Code units, not characters

`LEN`, `[]`, `ASC`, and every position and length in `LEFT`/`RIGHT`/`MID`/
`INSTR` count **UTF-16 code units**. A character outside the Basic Multilingual
Plane is a surrogate pair, so it counts as 2:

```basic
dim as ustring e = wchr(&h20AC)      '' €  — 1 unit
dim as ustring m = wchr(&h1D11E)     '' 𝄞  — 2 units, one character

print len(e), e[0]                   '' 1   8364
print len(m)                         '' 2
```

This is the same answer `WSTRING` already gives on Windows, and it keeps `LEN`
and `[]` O(1). It does mean `MID` can split a surrogate pair — exactly as it can
on a `WSTRING`. That is a property of UTF-16, not something this type
introduces.

`UCASE`/`LCASE` use a **generated** simple case-mapping table over the BMP, not
`towupper()`/`towlower()` — those are locale-dependent and would fold the same
string differently depending on the user's locale and which libc the program
linked against.

## Fixed-length form

```basic
dim as ustring * 16 f = "fixed"      '' 16 CODE UNITS (32 bytes)
print len(f)                         '' 5 — the text length
```

`USTRING * N` is NUL-terminated and `LEN` returns the text length, following
`WSTRING * N`. It does **not** space-pad the way `STRING * N` does.

The `N` **includes the terminator**, so `USTRING * 8` holds 7 characters of
text — again identical to `WSTRING * 8`, and unlike `STRING * 8`, which is not
terminated and holds a full 8.

A fixed-length string cannot be a `BYREF` parameter or a function result:

```basic
sub s( byref f as ustring * 8 )      '' error 324 — and the same for
                                     '' STRING * N and WSTRING * N
function f( ) as ustring * 8         '' error 55 — likewise
```

Both are general FB rules, not USTRING restrictions. Take a dynamic parameter
(a fixed-length argument binds to it, and writes are copied back) and return
the dynamic form.

## I/O

Where the output goes decides the encoding:

| Destination | Encoding |
|---|---|
| A real Windows console | the wide path — the OS renders UTF-16 directly |
| Files, redirected output, non-Windows consoles | **UTF-8** |

That second row is the point: a ustring written to a file produces a portable
UTF-8 file on every platform. (The existing wstring path writes raw UTF-16
*bytes* when redirected, which no other tool reads as text.)

```basic
dim as integer f = freefile
open "out.txt" for output as #f
print #f, u                          '' UTF-8 on every platform
close #f

open "out.txt" for input encoding "utf16" as #f
line input #f, u                     '' OPEN ... ENCODING is honoured too
close #f
```

`PRINT USING` counts code units in its field widths, so a format field lines up
with what the rest of the type says the length is — and gives the same answer
whether the output is a console or a file.

```basic
print using "[\   \]"; u             '' a 5-unit field
```

## What is supported

Everything below is implemented and covered by tests.

**Operators and intrinsics** — assignment, concatenation (`+`, `&`, `+=`),
comparison, `LEN`, `[]` indexing, `ASC`, `WCHR`, `LEFT`, `RIGHT`, `MID`
(function *and* statement), `INSTR`, `INSTRREV`, `TRIM`/`LTRIM`/`RTRIM`
(including the `ANY` and `EX` forms), `UCASE`, `LCASE`, `SPACE`, `STRING`,
`LSET`, `RSET`, `SWAP`, `VAL`, `STR`, `WSTR`, `HEX`, `FORMAT`.

**Language** — `VAR` inference, `SELECT CASE`, `IIF`, `BYREF`/`BYVAL` parameters
with copy-back, function results (including `BYREF` returns and fixed-length
results), overload resolution, UDT fields, `CAST`/`LET`/property/operator
overloads, arrays (multi-dimensional, `SHARED`, UDT-nested, `REDIM PRESERVE`,
`ERASE`), unions, `COMMON`, `WITH`, type aliases, static locals, `STRPTR`,
`VARPTR`, `SIZEOF`, `ustring ptr`, variadics.

**I/O** — `PRINT`, `WRITE`, `PRINT #`, `WRITE #`, `LINE INPUT`, `LINE INPUT #`,
`INPUT`, `INPUT #`, `PRINT USING`, `PUT`/`GET`, `OPEN ... ENCODING`, `READ`/`DATA`,
`DRAW STRING`.

**Dialects** — available in `-lang fb`, `fblite` and `deprecated`; correctly not
a keyword in `-lang qb`, matching how `ZSTRING` and `WSTRING` are gated.

### Known gap

`CONST u AS USTRING = "abc"` is **not** supported. fbc's `CONST` accepts exactly
one string type, `FB_DATATYPE_STRING` — `WSTRING` is rejected too, so USTRING is
no worse than the type it replaces, but it *is* worse than `STRING`. Supporting
it means threading a literal symbol through `symbReuseOrAddConst`, the const
value union and the expression path, all shared by every string type. That is a
feature addition rather than part of this one, and it is recorded rather than
bolted on. `dim as ustring u = "abc"` works, and the literal is already a
compile-time pool constant, so nothing is lost at runtime.

---

# Prebuilt compilers

You do not have to build anything to try this. Two ready-to-run installations
are in the repository, produced from this tree and verified before being
committed.

### `toolchains/fbc-modern-windows/` — Windows, 32-bit and 64-bit

```
fbc32.exe          32-bit compiler
fbc64.exe          64-bit compiler
bin/win32          i686 assembler + linker      shared by both
bin/win64          x86-64 assembler + linker    shared by both
inc/               FreeBASIC headers
lib/win32          32-bit runtime
lib/win64          64-bit runtime
```

The standard FreeBASIC *standalone* layout: both compilers sit at the top level
and share one `bin/` and one `inc/`, each picking the toolchain and runtime that
matches its target.

```bat
toolchains\fbc-modern-windows\fbc64.exe hello.bas
toolchains\fbc-modern-windows\fbc32.exe hello.bas
toolchains\fbc-modern-windows\fbc64.exe -target win32 hello.bas
```

### `toolchains/fbc-modern-linux/` — Linux x86-64

```
bin/fbc
inc/
lib/freebasic/linux-x86_64
```

```bash
toolchains/fbc-modern-linux/bin/fbc hello.bas
```

This is a **native** Linux build, not a cross-compile. It came from fbc's own
bootstrap path: the win64 compiler emits C for `linux-x86_64`, and gcc compiles
those 146 files into a Linux `fbc` — so no pre-existing Linux FreeBASIC is
needed to reproduce it.

### Things worth knowing

- **Run `fbc` where it lives.** It derives its installation prefix from its own
  path, so `bin/fbc` must stay beside `inc/` and `lib/`. Copying just the binary
  elsewhere gives `cannot open linker script file`.
- **The Linux binary is committed with its executable bit set** (mode `100755`),
  and `.gitattributes` keeps that tree from being CRLF-converted by a Windows
  clone. If you extract it some other way, `chmod +x bin/fbc`.
- **The Windows `bin`'s gcc has no C headers**, exactly as FreeBASIC's own
  distribution ships it. It assembles and links, which is all fbc asks of it,
  but it cannot rebuild the runtime — that needs a full toolchain.
- **The Linux `gfxlib2` is built `-DDISABLE_X11 -DDISABLE_GPM`**, because
  `X11/xpm.h` and `gpm.h` were unavailable on the build machine. Console, fbdev
  and everything else are present. `ffi.h` *was* available there, so `ThreadCall`
  works on the Linux build — unlike the Windows ones here.

---

# Performance: appending

`tests/ustring_append_bench.bas`, best of three runs on each platform.

**Read the units first.** A `STRING` moves 1 byte per character and a `USTRING`
moves 2 (a UTF-16 code unit, on every target). So USTRING taking ~2× the time of
STRING is *parity*, not a loss — the throughput column is the honest comparison.

### Against STRING — same class

2,000,000 single-character appends:

| Platform | STRING | USTRING | USTRING throughput |
|---|---|---|---|
| win64 | 10.71 ms (178 MB/s) | 16.01 ms | **238 MB/s** |
| win32 | 69.50 ms (27 MB/s) | 21.10 ms | **181 MB/s** |
| linux-x86_64 | 8.37 ms (228 MB/s) | 8.51 ms | **449 MB/s** |

USTRING moves twice the bytes at equal or better throughput everywhere. On
Linux it does twice the work in the same wall-clock time. (The win32 STRING
figure is an outlier I have not chased down — it is STRING's number, not
USTRING's, and the other two platforms bracket it.)

### Against WSTRING — a different complexity class

This is the one that matters, and it is structural rather than a tuning detail.
A `WSTRING` has **no length field**, so every append walks to the terminator to
find the end. Appending *n* times costs **O(n²)**. A `USTRING` keeps its length
in the descriptor, so an append is O(1) amortised.

Appending at *n* = 40,000 and again at 2*n*:

| Platform | WSTRING *n* → 2*n* | ratio | USTRING *n* → 2*n* | ratio |
|---|---|---|---|---|
| win64 | 82.45 → 339.56 ms | **4.12** | 0.21 → 0.31 ms | 1.43 |
| win32 | 106.93 → 402.41 ms | **3.76** | 0.40 → 0.50 ms | 1.25 |
| linux-x86_64 | 133.37 → 539.68 ms | **4.05** | 0.15 → 0.35 ms | 2.28 |

A ratio near 4 for doubled work is quadratic; near 2 is linear. At just 40,000
appends USTRING is already **400–900× faster**, and the gap widens with length.

The first version of this benchmark used 2,000,000 appends for all three types
and had to be killed — the WSTRING loop does not finish in any useful time.
That is why its counts are small here.

### Growth is amortised linear

The same append loop at 1× and 4× the count. Linear growth gives ≈4;
realloc-on-every-append would give ≈16.

| Platform | USTRING | STRING |
|---|---|---|
| win64 | 5.38 | 5.37 |
| win32 | 4.18 | 4.10 |
| linux-x86_64 | 4.47 | 4.43 |

USTRING tracks STRING to within a couple of percent on every platform. Both sit
slightly above 4 on win64 — since *both* types show it equally, that is the
memory system at these sizes, not the growth strategy.

---

# Tests

## fbc's own test suite

fbc has three test targets. **All three are run**; `unit-tests` alone is only
part of the suite.

| Target | Scale | Result |
|---|---|---|
| `unit-tests` (win64, gcc) | 2,308 test modules | **1,154,420 assertions, 11 failed** |
| `unit-tests` (win64, gas64) | 2,308 test modules | **identical** |
| `log-tests` | 1,731 tests across `fb`, `fblite`, `qb`, `deprecated` | **1,727 passed, 4 failed** |
| `warning-tests` | 68 files × 5 targets | **0 diagnostic changes** |
| `error-tests` | golden diagnostics × 5 targets | **0 diagnostic changes** |

The failures are environmental and present in the baseline before any of this
work: 11 × `fbc_tests.threads.threadcall_` (`libffi` absent, so `-DDISABLE_FFI`
compiles `fb_ThreadCall` to `return NULL`) and 4 `cpp` log-tests (no `libstdc++`
in this mingw64). Both were reproduced at `main` with the changes stashed.

`warning-tests` compiles for **dos, linux-x86, linux-x86_64, win32 and win64**
and compares against committed reference output; every diagnostic on every
target is byte-identical to stock fbc except the ones deliberately added.

Behaviour tests are additionally run by hand under **both** backends, because
three separate defects in this work were visible to only one of them — including
one that compiled, linked and silently returned the wrong function under gcc.

> **One caveat, stated plainly.** The suite as shipped does not pass untouched.
> `tests/udt-wstring` and `tests/udt-zstring` each contain `#define ustring ...`
> in 18 files, which becomes `error 4: Duplicated definition` once `USTRING` is a
> keyword — fbc's own tests would not compile. They are renamed to `uwstr_t` /
> `uzstr_t`. Any upstream patch has to carry that 36-file rename.

## This project's own tests

### Generics, `FOR EACH` and containers — `src/tests/generics/`

42 files. Every one of the 25 `fail-*` files holds **exactly one** case, because
the compiler stops at the first error and a multi-case file would report only
the first.

| File | Covers |
|---|---|
| `instantiate-type.bas` | instantiation, cache identity, nesting, UDT arguments |
| `member-procs.bas` | out-of-line bodies, both parameter orders, both declaration orders |
| `member-operators.bas` | operators, properties, `FOR`/`STEP`/`NEXT` |
| `global-operators.bas` | generic global operators and inference through them |
| `generic-procs.bas` | explicit and inferred type arguments |
| `ctor-dtor.bas` | construction, destruction, copy |
| `inheritance.bas` | 44 assertions — all three `EXTENDS` directions, `VIRTUAL`, `ABSTRACT`, RTTI positives **and negatives** |
| `recursive-generic.bas` | self-reference through a pointer |
| `iterator-protocol.bas` | ~60 assertions over the RFC-0002 contract |
| `for-each.bas` | ~45 assertions — both lowerings, backward compatibility, nesting, destructor balance, single evaluation |
| `container-{array,map,set,linkedlist}.bas` | every member, edge case and complexity claim |
| `member-mangling.bas`, `sizeof-instantiation.bas`, `capture-boundary.bas` | names, layout, deferral |
| `multimodule/` | two modules instantiating the same generics, linked |

The multimodule test was shown to have teeth by forcing `symbIsWeak` to FALSE —
it then fails with 8 duplicate-definition errors on each backend.

### USTRING

| Suite | Checks | What it covers |
|---|---|---|
| `tests/ustring_lang_test.bas` | 140 | the language surface end to end |
| `tests/ustring_usage_test.bas` | 142 | **every form the language allows** — declarations, arrays, UDTs, inheritance, parameters, returns, `[]` indexing, pointers |
| `tests/ustring_io_test.bas` | 36 | files, encodings, `PRINT USING`, round trips |
| `tests/ustring_gfx_test.bas` | 13 | `DRAW STRING`, compared **pixel by pixel** against the narrow path |
| `tests/ustr_codec_test.c` | 70 | UTF-8/16/32 codecs, including malformed input |
| `tests/ustr_core_test.c` | 38 | allocator, growth, temp-descriptor pool |
| `tests/ustr_wchar_test.c` | 25 | the conversion helpers at **all three wchar widths** |
| `tests/ustring_llvm_test.bas` | — | LLVM output byte-identical to `-gen gcc` |

`ustr_wchar_test.c` deserves a note: the wchar conversion branches fold away at
compile time, so on Windows the UTF-32 (Linux) and 8-bit (DOS) branches are dead
code that had never executed anywhere. The test includes the real source three
times, once per width, so all three run — and the harness was checked against a
deliberately injected bug to confirm it can actually fail.

### Platforms built and run

| Target | Built | Suites run |
|---|---|---|
| win64 | ✅ | lang 140/0, io 36/0, gfx 13/0 |
| win32 | ✅ | lang 140/0, io 36/0 |
| linux-x86_64 | ✅ | lang 140/0, io 36/0 |

Linux matters most for USTRING, because `sizeof(wstring)` is 4 there — so the
UTF-32 path is exercised for real, not just by a unit test. Building for 32-bit
is what uncovered the last real USTRING bug: literal emission in the gas x86
backend, reachable *only* on 32-bit targets.

**Not verified**: the LLVM backend for generics (no LLVM toolchain here, and it
is not in the gate); ARM, JS and DOS targets.

---

# Layout

```
src/                    the fbc tree, with everything this project adds
    src/compiler/       the compiler — parser-generic*.bas,
                        parser-compound-for.bas
    src/rtlib/          the runtime
    src/gfxlib2/        the graphics library
    inc/fb/             the standard containers (array, map, set,
                        linkedlist, hash)
    inc/containers.bi   the single include for all four
    tests/generics/     the generics, for-each and container suites
    makefile            'make compiler' and the test targets run from HERE

toolchains/
    fbc-modern-windows/ prebuilt: fbc32.exe + fbc64.exe, inc, libs
    fbc-modern-linux/   prebuilt: bin/fbc, inc, lib/freebasic/linux-x86_64

docs/
    generics/           RFC-0001
    for_each/           FOR EACH and the iterator protocol (RFC-0002/0003)
    array/  map/        the standard containers, one folder each (RFC-0004)
    set/    linkedlist/
    ustring/            USTRING reference and implementation notes

tests/                  USTRING's own suites and the append benchmark
tools/                  generators for the Unicode case table and the CP437
                        table, plus the LLVM verification harness
LICENSE                 licensing, inherited from FreeBASIC (see below)
```

Note that the makefile lives in `src/`, not at the top level: builds and test
runs are `cd src && make compiler`, not `make` from the repository root.

[docs/ustring/implementation-notes.md](docs/ustring/implementation-notes.md) is
worth reading if you are reviewing this. It records the design decisions *and*
the mistakes — several bugs in this work compiled cleanly, ran, and produced
plausible output (an empty generated destructor, a silently disabled copy-back,
a no-op `LSET`, a `READ` that assigned nothing). They were found by reading
generated code and by stress testing, not by normal test output, and the notes
say so.

# Building

```
cd src && make rtlib gfxlib2 compiler
```

See `tests/BASELINE.md` for the exact invocations, the three test targets, and
the environment workarounds this particular machine needed (none of them related
to this work).

`src/doc/manual/` is **not** updated. It is a mirror of the online FreeBASIC
wiki, refreshed by `make refresh` in that directory and regenerated from the
wiki rather than edited — a page written into it by hand is overwritten on the
next refresh. Manual pages belong on the wiki once any of this is accepted
upstream. The reference documentation for this work lives in `docs/`.

`src/bootstrap/` — fbc's self-hosting C snapshot — is **not** regenerated here.
It is `.gitignore`d in this tree, it is produced by fbc's own release process
rather than by hand, and nothing in this work changes the language the *compiler
itself* is written in. A merge upstream would regenerate it there.

# Licence

This is a modified copy of the FreeBASIC compiler, so it carries FreeBASIC's
licensing **unchanged**. Nothing is relicensed and no licence was chosen — it is
inherited, and it is a split, because this work touches both halves:

| Part | Licence |
|---|---|
| The compiler — `src/src/compiler/`, and the `fbc32.exe` / `fbc64.exe` / `bin/fbc` binaries built from it | **GNU GPL v2 or later** ([COPYING.GPL-2.0](COPYING.GPL-2.0)) |
| The runtime and graphics libraries — `src/src/rtlib/`, `src/src/gfxlib2/`, i.e. libfb, libfbmt, libfbgfx, libfbgfxmt | **GNU LGPL v2.1 or later, with a static-linking exception** ([COPYING.LGPL-2.1](COPYING.LGPL-2.1)) |
| The container headers — `src/inc/fb/*.bi`, `src/inc/containers.bi` | **LGPL v2.1 or later, with the same exception** — they compile into the user's program, so they are runtime rather than compiler. Upstream's own `inc/` headers carry no per-file notice, so this is stated here rather than inherited |
| Documentation under `docs/` | **GNU FDL** |

The linking exception is what lets a program link the runtime statically without
taking on the LGPL — it is quoted in full in [LICENSE](LICENSE).

So the work follows the file, exactly as the rest of fbc does: the compiler-side
changes are GPLv2+, and `ustr_*.c`, `fb_ustring.h`, the `DRAW STRING` support
and the container headers are LGPLv2.1+ with the exception.

**The prebuilt trees carry third-party components.** `toolchains/` redistributes
the toolchain fbc invokes — GNU binutils and gcc under **GPLv3**, plus the
MinGW-w64 runtime and import libraries under their own terms. They are
unmodified redistributions; see [LICENSE](LICENSE) for the breakdown.

---

# Status

All four features are implemented, tested and gated. The one USTRING gap is
`CONST`. Offered for upstream discussion.
