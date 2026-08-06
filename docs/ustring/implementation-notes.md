# USTRING implementation notes

Status and open decisions. See `tests/BASELINE.md` for the test baseline and the
environment workarounds this machine needs.

## Working now

`dim as ustring u` and `dim as ustring * N u` declare, assign, concatenate,
compare, report `LEN`, and destroy correctly. Generated C for a scope:

```c
FBUSTRING A$1;  __builtin_memset( &A$1, 0, 24ll );
FBUSTRING B$1;  __builtin_memset( &B$1, 0, 24ll );
FBUSTRING C$1;  __builtin_memset( &C$1, 0, 24ll );
__builtin_memset( &TMP$2$1, 0, 24ll );
FBUSTRING* vr$7 = fb_UStrConcat( &TMP$2$1, (void*)&A$1, -1ll, (void*)&B$1, -1ll );
fb_UStrAssign( (void*)&C$1, -1ll, (void*)vr$7, -1ll, 0 );
fb_UStrDelete( (FBUSTRING*)&C$1 );
fb_UStrDelete( (FBUSTRING*)&B$1 );
fb_UStrDelete( (FBUSTRING*)&A$1 );
```

`-1` is `FB_USTRSIZEVARLEN`, the var-len descriptor sentinel.

## Literals — done

`dim as ustring u = "hello"` works. Literals are converted at compile time, so
there is no runtime cost:

```c
fb_UStrInit( (void*)&U$0, -1ll,
             (void*)(uint16[]){0x0068,0x0065,0x006C,0x006C,0x006F,0x0000},
             -9223372036854775803ll, 0 );
```

(The size is `FB_STRISFIXED | 5`.)

Storage is a dedicated `littextu as ushort ptr` union member holding **raw
UTF-16 code units** — not escaped text like the z/wstring literals, so there is
no escape/unescape round trip to get wrong. `symbAllocUstrConst()` names the
symbol `{fbuc}` + hex of the units, which gives exact de-duplication.

Both lexer paths are covered and produce identical results, which cross-checks
the two decoders against each other:

| Source | Literal dtype | Path |
|---|---|---|
| no BOM | `CHAR` | bytes read as UTF-8 → `hUtf8ToUstr()` |
| UTF-8 BOM | `WCHAR` | host wchar → `hHostWstrToUstr()` |

The second is why the dedicated union member matters: the lexer decodes into the
**host** compiler's wchar width (fbc is self-hosted), 2 bytes on Windows and 4 on
Linux, so that path has to normalize. Reusing `littextw` would have stored
UTF-16 on one host and UTF-32 on the other.

### Backend literal emission

Each backend needs its own form, because none of the existing ones is
width-correct:

- **gcc** (`ir-hlc.bas`) — a C99 compound literal `(uint16[]){0x0068,…}`.
  Not `L"…"` (wchar_t-width) and not `"…"` (byte-oriented: a 16-bit unit's high
  NUL byte terminates it early — the first attempt emitted `"h\x00llo"`).
- **gas64** (`ir-gas64.bas`) — `.short 0x0068,…`. `.ascii` has the same
  early-termination problem.
- **llvm** (`ir-llvm.bas`) — escaped little-endian bytes,
  `[12 x i8] c"\68\00\65\00\6C\00\6C\00\6F\00\00\00"`. **Verified by inspecting
  the IR only** — `llc` is unavailable here, so it has never been assembled.

## Historical: why literals needed a storage decision

*Kept because the reasoning still governs anything else that stores ustring text.
Option 1 below is what was implemented.*

Compile-time literals were the obvious answer (zero runtime cost, matching how
`symbAllocWStrConst` handles wstring), but there was a trap in the obvious
implementation:

`FBS_VAR` stores literal text in a union of `littext as zstring ptr` /
`littextw as wstring ptr` (`symb.bi`). Reusing `littextw` for ustring literals
would work on Windows, where `wstring` is 2 bytes and therefore happens to match
a code unit — and would silently store the wrong width on Linux, where `wstring`
is 4 bytes.

That is precisely the class of bug USTRING exists to eliminate, and it would be
invisible to anyone developing on Windows. **fbc is self-hosted, so the width in
question is the HOST compiler's `wstring`, not the target's** — the same hazard
`env.wcharconv` already guards for wstring literal folding (`fb.bas:492`), and
which `hUnescapeW` still gets wrong (`hlp-str.bas`, it splits surrogates on host
width).

The three options were:

1. **A dedicated union member**, `littextu as ushort ptr`, with its own
   allocator. Correct by construction and host-width independent. **Chosen.**
2. **Store as UTF-8 in `littext`** and decode to UTF-16 at emit time. Reuses the
   existing zstring literal machinery, but every backend must do the decode.
3. **Reuse `littextw`** — rejected. Works on Windows, wrong on Linux.

Option 1 won because the whole point of the type is that its representation does
not vary by host or target, and the literal pool should not be the one place
that assumption breaks.

## VAR inference and multi-term concat — done

`VAR` infers the **dynamic** form from any ustring expression, including from a
`USTRING * N` — the N has nowhere to live on an expression dtype, and leaving it
fixed would produce a one-code-unit variable. Mirrors `zstring`/`STRING * N`
inferring to `STRING`.

Fixing this exposed a separate bug: `LEN` on a `USTRING * N` returned the
**capacity** rather than the text length, because `FB_USTRSETUP` took the length
from the size argument. The size carries the capacity (writers need it); readers
must walk to the terminator. `USTRING * N` follows `WSTRING * N` here, not
`STRING * N` — the latter space-pads, so its `LEN` genuinely is its capacity.

Multi-term concatenation lowers to one assign plus N concat-assigns, so nothing
is allocated per term. `u = a + b + c + d` emits:

```c
fb_UStrAssign      ( (void*)&U$0, -1ll, (void*)&A$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&B$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&C$0, -1ll, 0 );
fb_UStrConcatAssign( (void*)&U$0, -1ll, (void*)&D$0, -1ll, 0 );
```

Zero `fb_UStrConcat` calls, so zero temp descriptors.

This reuses `hOptStrMultConcat()`, which previously carried an `is_wstr` boolean
and branched on it at six points. A third string type does not fit a boolean, so
it now takes a dtype and dispatches through `hMultStrAssign()` /
`hMultStrConcatAssign()`. That is a change to code STRING and WSTRING both use —
verified by the full suite staying at 1154412 assertions, and by checking
directly that `s = a + b + c + d` on a STRING still emits one `fb_StrAssign`
plus three `fb_StrConcatAssign` and no `fb_StrConcat`.

A fixed-length destination is excluded from the rewrite, as `STRING * N` is: it
cannot grow, so the rewrite buys nothing.

**Phase 1 is complete.**

## Phase 2 — narrow interop, procedures (in progress)

Done: `STRING`/`ZSTRING` ↔ `USTRING` assignment, mixed concatenation in both
orders, cross-type comparison, `BYREF`/`BYVAL` parameters, and `FUNCTION … AS
USTRING`. Conversion is UTF-8 both ways with U+FFFD for malformed input, so it
is identical on every target — unlike `STRING` ↔ `WSTRING`, which goes through
the C locale.

Three bugs found by testing rather than by reading, all of which produced
plausible-looking output:

1. **`BYVAL` did not copy.** A ustring is non-trivial, so it always travels by
   address; without a temp copy the callee edited the caller's variable.
   `hAllocTempUString()` supplies the copy, mirroring `hAllocTempString()`.
2. **Discarded results leaked a pooled temp descriptor.** Only 256 exist, so a
   loop ignoring results exhausted the pool and every later call returned the
   null descriptor — reading as length 0, not as a crash. `ast-node-call.bas`
   now releases them.
3. **Multi-term concat corrupted mixed operands.** `hOptStrMultConcat` splits
   into per-operand appends and dispatched on the *destination* dtype, so a
   narrow operand was appended as raw code units: `"he"` became U+6568.
   `hMultStrConcatAssign()` decodes it first.

### wstring interop, overloads, copy-back

**`WSTRING` ↔ `USTRING`** in both directions, plus mixed concatenation and
comparison. The runtime branches on `sizeof(FB_WCHAR)`, so it is a copy where
wchar_t is 16 bits and a real UTF-16 ↔ UTF-32 re-encode where it is 32.

**The asymmetry the type was designed around** now shows up where it matters —
passing a ustring to a `WSTRING PTR` parameter:

```c
TAKEPTR( (uint16*)*(uint16**)&U$0 );   // Windows: pure reinterpret, no call
```

Zero conversion calls. Where wchar_t is wider there is no pointer to hand out,
so the compiler re-encodes **and warns** (`FB_WARNINGMSG_USTRTOWSTRCOPY`) — the
cost is invisible to anyone developing on Windows otherwise.

`USTRING` → `ZSTRING PTR` is deliberately a *mismatch* rather than a silent
conversion: a pointer needs a buffer of the right element width, and a ustring's
is 16-bit.

**Overload resolution.** All three string types share `FB_DATACLASS_STRING`, so
every call with more than one of them in scope was ambiguous. Ranking added in
`symbCalcArgMatch`: an exact family match outranks a cross-family one, a zstring
literal prefers `STRING`, and a wstring prefers `USTRING` (both are UTF-16, so
nothing is lost).

**Copy-back.** `BYREF` through a converting parameter writes the result back, or
`BYREF` is a lie for every non-ustring argument. The subtle part: the decision
has to be made *before* the conversion runs, because the conversion replaces the
argument with a CALL and the `astIsCALL` exclusion would then disable copy-back
for exactly the arguments that need it.

**Phase 2 is complete.**

## Phase 3 — intrinsics (core done)

`LEFT`, `RIGHT`, `MID` (function and statement), `INSTR`, `INSTRREV` (+`ANY`),
`TRIM`/`LTRIM`/`RTRIM` (+`ANY`/`EX`), `UCASE`, `LCASE`, `SPACE`, `STRING()`.

Positions and lengths are **code units**, 1-based. Searching by code unit is
safe for UTF-16 without any surrogate awareness: a surrogate half can never
equal a BMP unit, so a match cannot land mid-character — the thing a naive byte
search over UTF-8 would get wrong.

### The case table

`towupper`/`towlower` are unusable: they are locale-dependent, so the same
ustring would fold differently depending on the user's locale and on which libc
the program linked against. That is the platform divergence this type exists to
remove.

`tools/gen_case_table.py` generates `src/rtlib/ustr_casetable.c` from Python's
`unicodedata` (Unicode 15.1.0), as `[lo, hi, delta]` runs — ~660 runs per
direction instead of ~1170 pairs, binary searched. **Simple** mappings only: one
unit in, one out. Full case mapping can produce more than one character (German
sharp s upper-casing to `SS`), which an in-place unit transform cannot express
and which no other FB string type does either.

Surrogates are left alone. Mapping the halves of a pair independently would
corrupt the character, so an astral character passes through `UCASE` unchanged.

Verified for Latin-1 accents, Greek and Cyrillic, plus astral and CJK
pass-through.

### The rest: ASC, indexing, LSET/RSET, SWAP, numerics

`ASC` and `[]` both yield a **code unit**, so a non-ASCII BMP character reads as
its real codepoint value (`u[0]` of `"é"` is 233) — the thing a byte-oriented
string cannot do. A position holding a surrogate half yields that half.

`LSET`/`RSET` pad with spaces and never resize. `SWAP` exchanges the two
descriptors, which is O(1) and moves no text.

**The numeric intrinsics needed no ustring runtime at all.** `HEX`, `OCT`,
`BIN`, `STR` and the `VAL` family all produce or consume ASCII, so the existing
narrow versions plus UTF-8 conversion are already lossless. `VAL` only needed an
overload tiebreak — ustring→`STRING` now outranks ustring→`WSTRING`, since both
are lossless and the tie had to break somewhere. This does not affect Win32-style
APIs, whose parameters are `WSTRING PTR` and are ranked separately.

`WCHR` is how a ustring is built from a codepoint. `CHR` produces a single
*byte*, which is not valid UTF-8 above 127.

### Two bugs worth recording

**`SWAP` segfaulted under gas64.** A ustring fell through to the generic
temp-var swap (`tmp = l : l = r : r = tmp`), three full descriptor assignments,
which gas64 miscompiled. gcc happened to be fine — so this was invisible on the
default backend. Routed to `fb_UStrSwap` instead, which is both correct and
O(1).

**`LSET`/`RSET` compiled but did nothing.** `rtlStrLRSet` *emits* its call via
`astAdd()` rather than returning it, so my delegation returned a node nobody
added. The statement silently became a no-op — it compiled, ran, and changed
nothing.

`LEFT` and `RIGHT` needed two-parameter descriptor wrappers
(`fb_UStrLeftD`/`fb_UStrRightD`): they are registered as true overloads aliased
straight to a C function, so their signature is fixed and cannot carry the
`(ptr,size)` pair the rest of the API uses.

**Phase 3 is complete.**

## Phase 4 — aggregates (done), targets (partial)

UDT fields, fixed arrays and dynamic arrays all work, including deep copy: the
implicit ctor/copy-assign/dtor are generated for any UDT holding a ustring, and
`fb_ArrayDestructUStr` / `fb_ArrayUStrErase` destroy array elements.

**Two leaks were found and fixed**, both of which compiled and ran fine:

1. **The generated UDT destructor was emitted but EMPTY.** `hCallFieldDtor()`
   handled `FB_DATATYPE_STRING` but not `USTRING`, so every UDT holding a
   ustring leaked its field's buffer on every scope exit.
2. **Array scope exit emitted no destruction at all.** `rtlArrayErase`/the clear
   path had no ustring branch, so every element leaked.

Verified two ways: a descriptor-pool stress (20000 UDT scopes, 20000 array
scopes, 5000 redim/erase cycles, 5000 UDT-array scopes — a leak shows up as pool
exhaustion, which reads as length 0 rather than as a crash), and
`tests/ustring_memcheck.bas`, which allocates ~40 MB of ustring buffers across
40000 iterations and measures the working set: **16 KB growth, flat**.

### LLVM

`%FBUSTRING = type { i16*, i64, i64 }` is now emitted. Previously the IR
*referenced* the type without defining it, which llvm rejects outright.

The IR could not be assembled at the time this was written, and the reason
recorded here — an obsolete `llvm.memset` signature — was **wrong**. See
*The LLVM backend, now actually assembled* below for what it really is (three
pre-existing constructs, all reproducible with a plain `STRING` program) and for
the dynamic ustring path now being assembled, linked and run.

### Targets

Only win64 can be built and run here. The 32-bit path is verified as far as code
generation goes — `-target win32` emits
`typedef struct { uint16 *data; int32 len; int32 size; } FBUSTRING;`, a 12-byte
descriptor, and computes `sizeof(ustring * 8)` as 16 — but cannot be linked
(no 32-bit assembler installed). linux64, ARM, JS and DOS are untested.

## Phase 5 — I/O

`PRINT`, `PRINT #`, `WRITE`, `WRITE #`, `LINE INPUT #` and `INPUT #`.

### Where the output goes decides the encoding

| Destination | Path |
|---|---|
| real Windows console | the wide path — the OS renders UTF-16 directly, and fbc's cursor tracking (`POS`, `LOCATE`) stays correct |
| files, redirected output, non-Windows consoles | **UTF-8** |

The second row is the point. A ustring written to a file must produce a portable
file on every platform. The existing wstring path writes **raw UTF-16 bytes**
when output is redirected (`win32/io_printbuff_wstr.c`), producing a file no
other tool reads as text — a portable string type cannot behave that way.

Verified by reading the bytes back: `"héllo €"` lands on disk as
`68 C3 A9 6C 6C 6F 20 E2 82 AC`, and an astral character encodes to its 4 UTF-8
bytes rather than to a surrogate pair.

### Input reuses the narrow path

`LINE INPUT #` and `INPUT #` read into a temp `STRING` and convert. Since
`PRINT #` writes UTF-8, decoding bytes is both correct and free of new runtime
code — the whole narrow path, including maxlen handling, token splitting and
quoting rules, is reused unchanged.

### What this does NOT do

The existing **wstring** console bugs are untouched: `WriteConsoleOutputW` uses
one `CHAR_INFO` per UTF-16 unit so astral characters mis-render, and the Linux
path dumps raw UTF-32 when the console driver is uninitialised. Those are
pre-existing `WSTRING` defects. Fixing them would change existing wstring
behaviour, which is outside the additive scope this patch keeps to — and ustring
routes around them rather than inheriting them.

`OPEN ... ENCODING` is not wired for ustring: a ustring file is UTF-8 by
construction, so the encoding option has nothing to add yet. `PRINT USING` and
the graphics `DRAW STRING` path are also not wired.

## Phase 6 — upstream packaging

`changelog.txt` entry, `doc/ustring.txt`, `FBUSTRING` added to
`inc/fbc-int/string.bi`, and dialect gating confirmed: USTRING works in
`-lang fb`, `fblite` and `deprecated`, and is not a keyword in `-lang qb`,
matching how `ZSTRING`/`WSTRING` are gated.

### A real breakage, found late

`tests/udt-wstring` and `tests/udt-zstring` both contain `#define ustring ...`
(18 files each). With `USTRING` now a keyword that is `error 4: Duplicated
definition` — **fbc's own test suite would not compile**. Renamed to
`uwstr_t` / `uzstr_t`.

This was flagged in Phase 0 and then not acted on for five phases, because the
regression runs never caught it. Which brings us to:

### The verification failure

`clean-tests` is a target in the ROOT makefile, not in `tests/Makefile`. Running
`make clean-tests` from inside `tests/` silently does nothing. With the `.bas`
sources unchanged, make then considered all ~670 `.o` files up to date and
re-ran the *previous* `fbc-tests.exe`.

Every "the suite is unchanged at 1154412 assertions" claim from Phase 1 onward
was therefore re-executing a binary built at 14:36–14:41, before most of this
work existed. The runs were not measuring anything.

Corrected by deleting the objects and the executable explicitly. The clean
run compiles 670 files and reports **1154412 assertions / 11 failed** — the same
numbers, so the conclusion happened to hold, but it was not being demonstrated.
`tests/BASELINE.md` now documents the trap and how to confirm a rebuild really
happened (check the compile count in the log; it should be ~670, not 1).

## Status

Phases 0-6 complete. Verified on win64 only, under both `-gen gcc` and
`-gen gas64`:

| Suite | Checks |
|---|---|
| `tests/ustr_codec_test.c` | 70 |
| `tests/ustr_core_test.c` | 38 |
| `tests/ustr_wchar_test.c` | 25 (all three wchar widths) |
| `tests/ustring_lang_test.bas` | 140 |
| `tests/ustring_io_test.bas` | 36 |
| `tests/ustring_gfx_test.bas` | 13 |
| `tests/ustring_llvm_test.bas` | llvm output byte-identical to gcc |
| fbc `unit-tests` | 1154412 assertions, 11 failed (all pre-existing ThreadCall) |
| fbc `log-tests` | 1687 tests across fb/fblite/qb/deprecated, **0 failed** |
| fbc `warning-tests` | 68 files x 5 targets, **0 diagnostic changes** |

## PRINT USING

`fb_PrintUsingUStr` in `io_printusg.c`, beside the narrow and wide versions
(it needs that file's format-string context, which is file-local).

It parses into a `FB_UCHAR` buffer instead of converting to UTF-8 and
delegating to `fb_PrintUsingStr`, which would have been a fraction of the code.
It cannot: `fb_PrintUsingStr` counts **bytes**, so `\   \` applied to five
accented characters would consume ten bytes of a five-unit field and truncate —
and, worse, only when the output was redirected, since only that path is UTF-8.
The same program would format differently into a file than onto a console.

Counting code units also matches `LEN`, `[]` and every position in
`LEFT`/`MID`/`INSTR`.

Emission goes through a stack `FBUSTRING` handed to `fb_PrintUStr`, so the
console-vs-UTF-8 decision stays in `ustr_print.c` alone. The descriptor is not
from the temp pool and its `len` carries no `FB_TEMPSTRBIT`, so nothing frees it.

Checked against `STRING` and `WSTRING` on the same formats: ustring matches
STRING exactly on ASCII, including the degenerate ones (an unterminated `[\]`
field, more arguments than fields, a source longer than its field). It differs
from WSTRING only in that WSTRING writes raw UTF-16 bytes when redirected.

LPRINT USING needs no separate work — `rtlPrintUsing` reuses the same lookups.

## DRAW STRING

The starting point was not "unsupported" — it was **silently wrong**.
`draw string (x,y), u` already compiled, because a ustring satisfies the narrow
`byref as const string` parameter through the Phase 2 UTF-8 conversion. And
gfxlib2's font is indexed by **byte** (`char_data[(unsigned char)s->data[i]]`,
256 glyphs), so every non-ASCII character drew two or three garbage glyphs.
That was a regression against WSTRING, which at least gets one character to one
byte.

gfxlib2 has no Unicode font support at all and says so:

> `gfx_print_wstr.c`: "Unicode gfx font support is out of the scope of gfxlib,
> convert to ascii"

So the only real question is *which byte*. gfxlib2 answers it itself:

```c
fb_gfx.h:  #define FB_GFX_GET_CHARSET() "CP437"
```

Confirmed against the actual bitmap by rendering glyphs and dumping pixels —
byte `0x01` is a smiley, `0xE9` is theta, `0xDB` is a full block. CP437, not
Latin-1.

`fb_GfxDrawStringUStr` therefore maps each code unit through a generated CP437
table and delegates to `fb_GfxDrawString`. Unmappable → `'?'`; a surrogate pair
→ **one** `'?'`, since it is one character.

A table, not the locale. This deliberately diverges from the wstring precedent
(`fb_wstr_ConvToA`), which draws different glyphs depending on the machine's
locale — precisely what this type exists to stop.

A **custom** font is also byte-indexed, and its codepage is whatever its
author's bitmap says, which is unknowable from here. CP437 is a guess there, but
a far better one than UTF-8 bytes; anyone needing exact index control can pass a
STRING, whose bytes still go through untouched.

Tests compare **pixels**, not appearances: the ustring and the equivalent narrow
string are rendered to the same surface and the drawn bitmaps compared. The
check that matters is that U+0398 now renders identically to `chr(&hE9)` and
**differently** from its own UTF-8 bytes.

## OPEN ... ENCODING

Another one that was **silently wrong rather than missing** — and this one
corrupted data in both directions.

A ustring is UTF-8 on disk by construction, so the I/O path converted to UTF-8
first. An `ENCODING` file's device *also* encodes, so those UTF-8 bytes were
re-encoded as if each byte were a character:

```
ustring "héi" -> ENCODING "utf16"
  before:  FF FE 68 00 C3 00 A9 00 69 00     "hÃ©i"
  after:   FF FE 68 00 E9 00 69 00           what WSTRING writes
```

Reading was the mirror image: the device decoded UTF-16 to a single narrow byte
`0xE9`, which was then read as UTF-8, was malformed, and became **U+FFFD**. The
character was simply gone.

### Why it needs runtime entry points

`ENCODING` is a **runtime** property of the file, so this cannot be settled at
compile time the way the STRING/WSTRING split is. Hence `fb_FileLineInputUStr`
and `fb_InputUStr` in `ustr_fileio.c`, plus a branch in `fb_PrintUStr` /
`fb_WriteUStr`, all switching on `handle->encod`:

| `handle->encod` | path |
|---|---|
| `FB_FILE_ENCOD_ASCII` | narrow — plain bytes, and a ustring file is UTF-8 |
| anything else | wide — the device encodes/decodes, exactly as for WSTRING |

The console keeps the old temp-STRING path for LINE INPUT: it has no encoding,
and that path carries all the prompt and maxlen handling.

The encoded `LINE INPUT #` grows its own buffer rather than calling
`fb_FileLineInputWstr`, which needs a caller-supplied maximum and truncates past
it. A plain-file read has no line limit, so an encoded read must not acquire
one — a silent truncation that appears only for encoded files is precisely the
kind of bug this work keeps turning up. Tested with a 1000-unit line, which
crosses the 256-unit initial buffer several times.

`INPUT #` has no such asymmetry: both tokenisers bound a token at
`FB_INPUT_MAXSTRINGLEN`, so a ustring is neither more nor less capable than a
wstring.

### The trap: a hardcoded array bound

`rtl-file.bas` declares its funcdata table as `funcdata( 0 to 71 )` — a
**hardcoded** bound. Adding rows without bumping it fails as a confusing syntax
error a hundred lines away (`error 65: Expected '}'`). Its siblings
`rtl-print.bas` and `rtl-gfx.bas` use `0 to ...` and infer it, which is why the
PRINT USING and DRAW STRING rows needed no such change.

Tests compare against **WSTRING's bytes**, not against hand-written
expectations — wstring has always been right here, so it is the reference. All
three encodings, both directions, plus a check that a plain file is still
untouched UTF-8.

## The LLVM backend, now actually assembled

This was previously recorded as "verified by reading the IR", with the reason
given as an obsolete `llvm.memset` signature. **That reason was wrong.** Running
it down properly, a modern clang rejects fbc 1.20's IR for three separate
things, none of them ustring's - a plain STRING program fails identically:

| # | Construct | Status |
|---|---|---|
| 1 | `@llvm.global_ctors` in the obsolete 2-field form | patched by the shim |
| 2 | typed pointers (`i8*`), removed in LLVM 17 | patched by the shim |
| 3 | a **constant-expression** `bitcast` of a function-local `alloca` | not patchable |

(3) is emitted for every fixed-length local:

```llvm
%vr97 = bitcast i16* bitcast ([16 x i8]* %F.8 to i16*) to i8*
```

`WSTRING * N` and `ZSTRING * N` emit the **identical** construct, which is how
we know it is a pre-existing backend bug rather than something ustring
introduced. It does mean `USTRING * N` cannot be assembled here, so
`ustring_llvm_test.bas` deliberately omits it and leaves that form to the gcc
and gas64 suites, which cover it.

With (1) and (2) rewritten by `tools/modernize_ll.py`, the **dynamic** ustring
path assembles, links and runs - and its output is **byte-identical** to the
`-gen gcc` build. So the `%FBUSTRING` type definition, the literal byte arrays
and the runtime call signatures are now executed rather than eyeballed. The
euro check (`e[0]` = 8364) is the one that matters: it proves a non-ASCII
literal survives the llvm backend's escaped little-endian emission at the right
width.

```bash
sh tools/check_llvm.sh
```

The shim is a test harness, not a proposed fix. Emitting the current dialect is
fbc's llvm backend's own job and is out of scope here.

## The other wchar widths, actually executed

`hWcharToUnits` / `hUnitsToWchar` branch on `sizeof(FB_WCHAR)`, and those
branches **fold away at compile time**. On Windows FB_WCHAR is 16 bits, so the
UTF-32 branch (Linux) and the 8-bit branch (DOS) were never compiled into
anything runnable. Dead code is untested code — and it is exactly the code a
Windows developer cannot check, while every claim about ustring on Linux runs
straight through it.

The two helpers moved out of `ustr_convw.c` into `ustr_wchar_conv.h`, which
`tests/ustr_wchar_test.c` includes **three times**, once per width, renaming the
functions each time. So all three branches run natively, against *that* source
rather than a copy of it — a test of a copied function would prove nothing.

25 checks. The ones that matter are the ones only the UTF-32 branch can pass:

| Check | Why |
|---|---|
| `U+1D11E` → `D834 DD1E` | an astral scalar becomes a surrogate pair |
| measure counts **5** for 3 scalars | the unit count is not the character count; getting this wrong under-allocates and truncates **on Linux only** |
| `0x110000`, lone surrogate → `U+FFFD` | not valid scalars in UTF-32 either |
| 6 units → 5 chars → 6 units | round trip through the Linux representation |
| lone surrogate stays 2 chars | must not swallow its neighbour |
| `0xE9` → `U+00E9`, not `U+FFE9` | the DOS cast goes through **unsigned** char |
| short buffer reports the full count, writes nothing past capacity | truncation safety in every branch |

### The harness was checked against a deliberate bug

A passing test proves nothing until it has been seen to fail. Swapping
`FB_UCHAR_CP_LOWSUR` for `FB_UCHAR_CP_HIGHSUR` in the UTF-32 branch produces:

```
FAIL w32 astral -> surrogate pair
  got  [0061 D834 D834 0062]
  want [0061 D834 DD1E 0062]
25 checks, 2 failed
```

so the branch really is being executed, and the assertions really do bite.

This does **not** make ustring verified on Linux or DOS — nothing has been built
or run on those targets. It makes the *width-dependent conversion logic*
verified at all three widths, which was the single largest piece of never-
executed code in the implementation.

## Feature-completeness sweep

Rather than assume, every string-shaped language surface was probed with a
one-file snippet, with STRING and WSTRING compiled as controls. Confirmed
working: `SELECT CASE`, `IIF`, `STRPTR`/`VARPTR`/`SADD`, `ustring ptr`,
`PUT`/`GET`, `REDIM PRESERVE`, `ERASE`, UDT `CAST`/`LET`/property/operator
overloads, `BYREF` returns, `COMMON`, unions, `SIZEOF`, type aliases, static
locals, 2-D and UDT-nested arrays, `WITH`, variadics, `MID` statement, console
`INPUT`/`LINE INPUT`, `ENVIRON`, `COMMAND`, `STR`/`VAL`/`HEX`/`WSTR`/`FORMAT`,
fixed-length function results.

Two things turned up.

### READ silently did nothing (fixed)

A USTRING fell through `rtlDataRead`'s `case else`, which returns FALSE. The
single-destination form then **compiled cleanly and did nothing** — no
diagnostic, no assignment, the variable kept its old value:

```
ustring READ gave: [UNCHANGED]
string  READ gave: [alpha]
```

The multi-item form failed differently, as `error 3: Expected End-of-Line`,
because the FALSE aborted the parser's comma loop — so `read x, y` broke
whenever the ustring was not last.

Fixed with the temp-STRING-and-convert pattern. Unlike `INPUT #` this needs no
runtime branch: DATA literals come from the **source file**, not a file device,
so there is no `ENCODING` in play and the bytes are UTF-8.

### CONST is not supported (not fixed)

`const u as ustring = "abc"` is rejected. `parser-decl-const.bas` accepts
exactly one string type, `FB_DATATYPE_STRING`; **WSTRING is rejected too**, so
ustring is no worse than the type it replaces — but it is worse than STRING,
and the type's promise is that it works anywhere STRING does.

Supporting it means carrying a `{fbuc}` literal symbol through
`symbReuseOrAddConst`, the const value union and the expression path — shared
machinery all three string types use. That is a feature addition, not a bug fix,
and it was left alone rather than bolted on. The practical cost is small:
`dim as ustring u = "abc"` works, a ustring literal is already a compile-time
pool constant, so nothing is lost at runtime.

## Three compilers built: win32, win64, linux-x86_64

| Output | Contents |
|---|---|
| `fbc-win/` | `fbc32.exe` + `fbc64.exe`, sharing one `bin/` (win32 + win64 toolchains), `inc/`, `lib/win32`, `lib/win64` — the standard FB standalone layout |
| `fbc-linux/` | `bin/fbc`, `inc/`, `lib/freebasic/linux-x86_64` |

Linux was built **natively in WSL** rather than cross-compiled, using fbc's own
bootstrap path: the win64 fbc emits C for `linux-x86_64` (`-target linux-x86_64
-r`), and gcc inside WSL compiles those 146 files into a Linux `fbc`. No
pre-existing Linux fbc is needed.

### The 32-bit build found a real bug

`USTRING * N` literals were emitted by the **32-bit x86 emitter** as:

```
_Lt_0005:	.ascii	h
```

which the assembler rejects outright. Literal emission had been fixed for gcc,
gas64 and llvm — but `emit_x86.bas` is reached **only** on 32-bit, and until
there was a 32-bit compiler to run, nothing could reach it. Two distinct
defects:

1. `_getTypeString()` mapped `FB_DATATYPE_FIXUSTR` into the `.ascii` group. A
   code unit is 16 bits, so it needs `.short` — the same reasoning as gas64.
2. `hEmitVarConst()` had no `FIXUSTR` case, so it fell through to `case else`
   and read the **narrow** `littext`, which a ustring literal does not use.

And a third, found only because the first fix half-worked: `stext` is a local in
a `static` sub, and every other branch **assigns** to it while mine appended. So
each literal inherited every previous one:

```
_Lt_0042:	.short	" want= "0x0061,0x0062,...0x0000 0x0077,...
```

### Verified

| Compiler | lang | io | fbc unit-tests |
|---|---|---|---|
| `fbc-win/fbc32.exe` | 140/0 | 36/0 | 1613096 assertions, 11 failed |
| `fbc-win/fbc64.exe` | 140/0 | 36/0 | 1154412 assertions, 11 failed |
| `fbc64 -target win32` | 140/0 | — | — |
| `fbc-linux/bin/fbc` | 140/0 | 36/0 | not run |

The 11 are the same pre-existing ThreadCall failures in both Windows runs. The
32-bit total differs because 32-bit builds more modules (2311 vs 2302).

### Linux confirms the UTF-32 path in production

`sizeof(wstring)` is 4 there, so the branch that only a unit test had exercised
is now real:

```
ustring units   = 4      h + e-acute + astral (surrogate pair)
sizeof(wstring) = 4
wstring chars   = 3      the pair collapses to one scalar
roundtrip units = 4
identical       = -1
```

The `USTRING copied to a temporary WSTRING` warning also fires there for real,
which on Windows is unreachable by construction.

### Build notes

- The FB 1.10.1 bundle's `bin/win32`/`bin/win64` gcc ships **without C headers** —
  it can assemble and link but cannot build the rtlib. Real toolchains are
  needed for that (`C:/dev/utils/mingw32`, `C:/dev/utils/mingw64`); the bundle's
  `bin/` is what gets *shipped*, since that is all fbc invokes at runtime.
- mingw32's binutils are unprefixed, so `AS`/`AR` must be passed explicitly
  while `CC` stays prefixed.
- Linux: only `gpm.h` was missing, so the rtlib needs `-DDISABLE_GPM`; gfxlib2
  additionally needs `-DDISABLE_X11` because `X11/xpm.h` is absent. `ffi.h` IS
  present there, so ThreadCall actually works on the Linux build.
- fbc derives its prefix from its own path, so `bin/fbc` must be run in place.

## Append performance

`tests/ustring_append_bench.bas`, best of three per measurement.

Raw numbers, all three platforms:

```
                              win64        win32        linux-x86_64
1-char append x 2,000,000
  STRING                     10.71 ms     69.50 ms      8.37 ms
  USTRING                    16.01 ms     21.10 ms      8.51 ms
32-char append x 500,000
  STRING                     43.06 ms     48.79 ms      2.69 ms
  USTRING                    88.32 ms     80.28 ms      7.49 ms
u = a + b + c + d x 1,000,000
  STRING                     31.64 ms    109.59 ms     30.08 ms
  USTRING                    69.00 ms    126.34 ms     53.28 ms
WSTRING vs USTRING, n=40,000 then 2n
  WSTRING            82.45 / 339.56   106.93 / 402.41   133.37 / 539.68
  USTRING             0.21 /   0.31     0.40 /   0.50     0.15 /   0.35
growth ratio, 4x work
  USTRING                      5.38         4.18          4.47
  STRING                       5.37         4.10          4.43
```

### What is solid, and what is not

**Solid.** USTRING moves 2 bytes per character to STRING's 1, and lands at equal
or better *throughput* on all three platforms. Growth is amortised linear and
tracks STRING to within a couple of percent everywhere — the important negative
result, since a naive implementation reallocating on every append would show ~16
rather than ~4.

**Solid, and the real headline.** WSTRING append is **O(n²)** — it has no length
field, so `fb_WstrConcatAssign` walks to the terminator every time. The ratio is
~4 for doubled work on every platform, against USTRING's ~1.4–2.3. At 40,000
appends USTRING is already 400–900× faster.

The first version of this benchmark ran all three types at 2,000,000 appends and
had to be **killed** — the WSTRING loop never finishes. That is what prompted
giving WSTRING its own small-n scaling test instead of a single-point timing,
which is a far more informative comparison anyway.

**Not solid, and not chased down.** Two individual figures look off and are
STRING's, not USTRING's: win32 STRING single-char at 27 MB/s (the other two
platforms are 178 and 228), and Linux STRING 32-char at 5.6 GB/s, which smells
like realloc-in-place or the optimiser. They are recorded as measured rather
than smoothed, and no conclusion rests on either.

Both types sit slightly above 4.0 on the win64 growth ratio. Since *both* show
it equally it is the memory system at those sizes, not the growth strategy.

## The usage showcase, and the five bugs it found

`tests/ustring_usage_test.bas` — 142 checks. Written to exercise USTRING in
*every* form the language allows: all declaration syntaxes, dynamic and fixed,
arrays (static, dynamic, multi-dimensional, initialised, UDT-nested), UDTs with
constructors/destructors/properties/operator overloads, inheritance with virtual
methods, every parameter mode, every return form, `[]` indexing, and pointers.

Writing it found **five real bugs**, none of which the existing suites reached.
That is the lesson worth recording: the suites tested what I thought to test.

| # | Bug | Symptom |
|---|---|---|
| 1 | `MID` statement was a **no-op** | compiled, ran, changed nothing |
| 2 | `STRPTR` on a var-len ustring returned the **descriptor** | `STRPTR = VARPTR`, typed `CHAR PTR` |
| 3 | Copy-back missing for a `USTRING * N` **argument** | callee's writes silently discarded |
| 4 | `USTRING * N` accepted as a **function result** | miscompiled — pointer truncated to 16 bits |
| 5 | `(*p)[0]` on a ustring **failed to parse** | worked for STRING |

### 1. MID statement — the LSET bug, again

`rtlUStrAssignMid()` built the call node and returned it without `astAdd()`.
`cMidStmt` only checks the result for NULL, and the narrow `rtlStrAssignMid()`
adds the node itself before returning. So it reported success and emitted
nothing.

**This is the identical mistake as `rtlStrLRSet` in phase 3.** Same root cause,
same silent shape, found the same way — by checking a result rather than
trusting a clean compile. Worth noting that knowing about a bug class once did
not stop me writing it a second time.

### 2. STRPTR returned the wrong pointer

The `select case` in `cStrIdxOrMemberDeref`'s sibling in `parser-expr-unary.bas`
handled `FB_DATATYPE_STRING` via `astBuildStrPtr()` and let everything else fall
to `case else`, which takes `@expr`. For a var-len ustring that is the
descriptor's address, not the text — so `STRPTR(u) = VARPTR(u)`, which is simply
wrong for a dynamic string, and typed `CHAR PTR` on top.

Fixed with `astBuildUStrDataPtr()`, deliberately separate from the existing
`astBuildUStrPtr()`: that one yields a `WCHAR PTR` and asserts wchar is 16 bits,
so it is Windows-only. `STRPTR` must work everywhere, and a code unit is uint16
on every target, so `USHORT PTR` is the honest element type.

### 3. Copy-back for fixed-length arguments

The guard read `if( typeIsUstring( argdtype ) = FALSE )`, which excludes **both**
ustring forms — but only the var-len form is passed as-is and so needs no
write-back. A `USTRING * N` goes through a temp like any converted argument, so
it needs copy-back, and `STRING * N` and `WSTRING * N` both do it. Narrowed to
`argdtype <> FB_DATATYPE_USTRING`.

### 4. Fixed-length function results

`parser-proc.bas` rejects `STRING * N` and `WSTRING * N` results (error 55).
`FIXUSTR` was missing from that `select case`, so it was accepted — and the gcc
backend then emitted `uint16 R_FIXED( void )`, truncating a returned pointer to
16 bits. Added to the `WCHAR` arm, which is the rule USTRING follows elsewhere.

Only found because the generated C carried a warning I read:
`cast to pointer from integer of different size`.

### 5. Indexing a parenthesised expression

`cStrIdxOrMemberDeref` listed CHAR/WCHAR/STRING/FIXSTR. Without the ustring
types, `(*p)[0]` gave *Expected End-of-Line, found '['* while the same
expression on a STRING worked.

### What is confirmed *not* a USTRING limitation

Checked against STRING and WSTRING controls rather than assumed:

- `byref f as ustring * 8` → `error 324`. Identical for `STRING * N`,
  `ZSTRING * N`, `WSTRING * N` — a general FB rule.
- `r(t) = "x"` on a BYREF result → `error 58`, and the same for STRING.
- `CAST(ustring, x)` → so does `CAST(string, x)`; casting *to* a string type is
  not an fbc feature.
- `USTRING * 8` holds 7 characters + terminator, exactly like `WSTRING * 8`.
  `STRING * 8` holds 8 because it is not terminated.
- `UCASE` leaves the German sharp s alone: simple case mapping only, one unit in
  and one out, which is the documented behaviour and what every other FB string
  type does.

Verified on all three compilers: 142/0 under win32, win64 and linux-x86_64. The
fbc suite is unchanged at 1154412 / 11 after all five fixes.

Still open: `CONST`; ARM/JS/DOS remain unbuilt; and `USTRING * N` under
`-gen llvm` is blocked by the pre-existing backend bug.
