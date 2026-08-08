# RFC-0006 — Custom pattern format and parse

Status: **draft** · Phase 6 · Depends on: [RFC-0001](RFC-0001-core-representation.md), [RFC-0005](RFC-0005-iso8601.md)

A deterministic, locale-free formatter and strict parser driven by a pattern
string: `"yyyy-MM-dd HH:mm:ss"`. Portable C, no OS calls.

Locale-*dependent* formatting is a separate thing and lives in
[RFC-0007](RFC-0007-zones-locale-interop.md) §3. This RFC's output depends only
on the value and the pattern, which is what makes it testable by exact string
assertion and what makes it safe to write to a file another program will read.

## 1. Why this shape

The candidates were .NET/Java pattern letters (`yyyy-MM-dd`), C `strftime`
(`%Y-%m-%d`), and Go's reference-time layout (`2006-01-02`).

Pattern letters won on familiarity: it is what C#, Java, Rust's `chrono`,
Temporal's polyfills, ICU and every spreadsheet use, and it is closest to what
AfxNova's Win32 picture masks already do — so the existing FB Win32 audience
reads it without a manual. `strftime` was rejected for its opaque single letters
and its locale-dependent specifiers; Go's layout was rejected as unteachable
outside Go.

## 2. Pattern letters

A run of the same letter is one field; the run length selects the width.
Anything not a pattern letter is literal, except the quoting characters in §3.

### Date

| Pattern | Meaning | Example (2025-03-04) |
|---|---|---|
| `y` | Year, minimum digits | `2025` |
| `yy` | Year, last two digits | `25` |
| `yyyy` | Year, 4 digits zero-padded | `2025` |
| `yyyyy` | Year, 5 digits zero-padded | `02025` |
| `M` | Month, 1–2 digits | `3` |
| `MM` | Month, 2 digits | `03` |
| `MMM` | Month abbreviation, **invariant English** | `Mar` |
| `MMMM` | Month name, **invariant English** | `March` |
| `d` | Day of month, 1–2 digits | `4` |
| `dd` | Day of month, 2 digits | `04` |
| `ddd` | Weekday abbreviation, **invariant English** | `Tue` |
| `dddd` | Weekday name, **invariant English** | `Tuesday` |
| `D` | Day of year, 1–3 digits | `63` |
| `DDD` | Day of year, 3 digits | `063` |
| `Q` | Quarter, 1 digit — **format-only** | `1` |
| `w` | ISO week, 1–2 digits — **format-only** | `10` |
| `ww` | ISO week, 2 digits — **format-only** | `10` |
| `Y` | ISO week-year, 4 digits — **format-only** | `2025` |
| `g` | Era — **format-only** | `A.D.` |

`MMM`/`MMMM`/`ddd`/`dddd` emit **invariant English** names from a built-in
table, not the OS locale. This is the whole point of this RFC: a pattern
formatter whose output changes with the machine's locale cannot be used to write
a file. Localized names are RFC-0007's job.

### Time

| Pattern | Meaning | Example (14:30:05.1234567) |
|---|---|---|
| `H` | Hour 0–23, 1–2 digits | `14` |
| `HH` | Hour 0–23, 2 digits | `14` |
| `h` | Hour 1–12, 1–2 digits | `2` |
| `hh` | Hour 1–12, 2 digits | `02` |
| `m` / `mm` | Minute | `30` |
| `s` / `ss` | Second | `05` |
| `f` … `fffffff` | Fractional, 1–7 digits, **zero-padded, always shown** | `fff` → `123` |
| `F` … `FFFFFFF` | Fractional, 1–7 digits, **trailing zeros and the whole field omitted if zero** | |
| `t` | AM/PM first letter, invariant | `P` |
| `tt` | AM/PM, invariant | `PM` |

The `f` versus `F` distinction is C#'s and it earns its keep: `f` for
fixed-width sortable output, `F` for human-readable output that does not say
`.000`.

### Offset and zone

| Pattern | Meaning | Example |
|---|---|---|
| `z` | Offset, sign + hours | `+5` |
| `zz` | Offset, sign + 2-digit hours | `+05` |
| `zzz` | Offset, `±HH:MM` | `+05:30` |
| `K` | `Z` if UTC, `±HH:MM` if offset, empty if unspecified | `Z` |

`K` is the one to use for machine-readable output; it is what makes a pattern
round-trip an unspecified `DateTime` correctly.

## 3. Literals and escaping

- `'text'` — single quotes delimit a literal run. `''` inside is a literal
  apostrophe.
- `\c` — backslash escapes the single next character.
- Any character that is not a pattern letter (`a`–`z`, `A`–`Z`) is literal
  without quoting: `-`, `/`, `:`, `.`, `,`, space, digits, everything else.
- An unterminated quote is a **pattern error**.
- An unrecognized ASCII letter is a **pattern error**, not a literal. Silently
  passing through an unknown letter turns a typo into wrong output; failing
  turns it into a caught bug. (This is where .NET's behaviour is wrong and Java's
  is right.)

## 4. API

```freebasic
' formatting
declare function ToString( byref pattern as string ) as string
declare function TryFormat( byref pattern as string, byref result as string ) as boolean

' parsing
declare static function TryParseExact( byref s as string, byref pattern as string, _
                                       byref result as DateTime ) as boolean
declare static function ParseExact( byref s as string, byref pattern as string ) as DateTime
```

A pattern error, or an `Invalid` receiver, makes `ToString` return the empty
string and `TryFormat` return `false`. `TryFormat` exists so a caller can
distinguish "the pattern is broken" from "the value formatted to nothing".

### Constant-format shorthands

A pattern of exactly one character is a named format, not a field:

| Pattern | Meaning | Output |
|---|---|---|
| `"o"` / `"O"` | Round-trip ISO 8601 — identical to RFC-0005 `ToIsoString` | `2025-03-04T14:30:05.1234567Z` |
| `"s"` | Sortable, second resolution, no offset | `2025-03-04T14:30:05` |
| `"u"` | Universal sortable | `2025-03-04 14:30:05Z` |
| `"R"` | RFC 1123, for HTTP headers (converted to UTC first) | `Tue, 04 Mar 2025 09:00:05 GMT` |
| `"d"` | Invariant short date | `2025-03-04` |
| `"T"` | Invariant time | `14:30:05` |

To format a single pattern letter as a field, use a two-character pattern with a
literal (`"%d"` is not adopted; write `"d "` and trim, or quote it). This is a
known wart in the C# design; the shorthands are worth it.

`"R"` deliberately emits `GMT` and English names regardless of locale and
regardless of the value's offset — the value is converted to UTC first. That is
what RFC 1123 requires, and getting it wrong is the classic HTTP-header bug.

## 5. Parse semantics

`TryParseExact` is strict:

1. The input must match the pattern **exactly**. No leading or trailing
   characters, no whitespace flexibility beyond a literal space in the pattern
   matching exactly one space.
2. Fixed-width fields (`MM`, `dd`, `HH`, `yyyy`, `fff`) consume exactly that many
   digits. Variable-width fields (`M`, `d`, `H`) consume 1–2 digits greedily,
   stopping at a non-digit.
3. A variable-width numeric field immediately followed in the pattern by another
   numeric field is a **pattern error** — `"Md"` cannot be parsed
   unambiguously, and failing at pattern-compile time is better than failing on
   the 3rd of December.
4. Name fields (`MMM`, `dddd`) match invariant English, case-insensitively.
5. Fields not present in the pattern default to: year 1, month 1, day 1, all
   time components 0, offset unspecified.
6. A field appearing twice with **conflicting** values is a failure
   (`"yyyy-MM-dd MM"` given `2025-03-04 05`).
7. Redundant-but-consistent fields are accepted and cross-checked: a pattern
   with both `dddd` and `yyyy-MM-dd` fails if the named weekday is not the
   weekday of that date.
8. The assembled components go through RFC-0001's constructor, so out-of-range
   values (`2025-02-30`) fail there.
9. Same contract as RFC-0005 §3: `result` is always written; `Invalid` on
   failure; never raises `err()`.

Most of the pattern surface parses as well as it formats, but **not all of it**.
These are format-only, and using one in a parse pattern is a *pattern error*
(return 2), not a silent success:

- `Q`, `w`, `ww` — a quarter or a week number cannot reconstruct a date, and
  cross-checking one adds machinery for no real benefit.
- `Y` — the ISO week-year is derived, not independent.
- `g` — an era carries no information in a range that is entirely A.D.
- `"R"` and `"u"` — the constant formats that convert to UTC.

`"o"`, `"O"`, `"s"`, `"d"` and `"T"` parse. An earlier draft of this section
claimed the compiler served both directions with only `"R"`/`"u"` excepted; the
list above is what actually shipped.

**Two implementation notes that are easy to get wrong**, both found by the
tests:

- A literal `T` inside a constant-format expansion must be **quoted**
  (`yyyy-MM-dd'T'HH:mm:ss`), or it hits the unknown-letter rule above and the
  whole format fails. This silently produced an empty string for `"s"` until a
  test caught it.
- An `F` field that vanishes must take an adjacent literal `.` with it, and —
  symmetrically — that `.` must be **optional on parse**, or `HH:mm:ss.FFF`
  formats a value without the dot and then fails to parse its own output.

## 6. Tests

Suite `fbc_tests.chrono.pattern`.

**Format table** — at least 120 (value, pattern, expected string) rows. Every
pattern letter at every supported run length, against: a value with zero
sub-seconds and one with non-zero; a single-digit month/day/hour (exercising
both padded and unpadded); midnight and noon (`h`/`tt` edge cases — 00:00 must
render as `12 AM`, 12:00 as `12 PM`); UTC, offset, and unspecified (`K` and
`zzz`); year 1 and year 9999.

**`f` versus `F`** — a dedicated table. `.1200000` under `fff` is `120`, under
`FFF` is `12`; `.0000000` under `fff` is `000`, under `FFF` is empty and takes
any adjacent literal `.` with it.

**Literals and escaping** — `'at'`, `''`, `\H`, unquoted punctuation,
unterminated quote (pattern error), unknown letter `Z`/`P`/`x` (pattern error,
*not* passed through).

**Parse table** — at least 100 rows, exact ticks and offset asserted, mirroring
the format table.

**Parse rejection** — at least 50 rows: trailing garbage; missing field;
wrong separator; `MM` given one digit; `M` given three digits; the
ambiguous-pattern error (`"Md"`); conflicting duplicate field; inconsistent
weekday cross-check (`"dddd yyyy-MM-dd"` given `Monday 2025-03-04`, which is a
Tuesday); out-of-range component.

**Round trip** — for each of a set of round-trippable patterns
(`"yyyy-MM-ddTHH:mm:ss.fffffffK"`, `"yyyy-MM-dd HH:mm:ss"`, `"o"`) × 10,000
fixed-seed values: `ParseExact( ToString( p ), p )` equals the value, truncated
to the pattern's precision. The truncation is part of the assertion, not an
excuse for a loose comparison.

**`"o"` agrees with RFC-0005** — `ToString("o")` is byte-identical to
`ToIsoString()` for the whole RFC-0005 emission table. One implementation, two
entry points; this test is what keeps them from drifting.

**`"R"` correctness** — English names and `GMT` under a non-English locale; a
value with a `+05:30` offset renders as the corresponding UTC time.

**No locale leakage** — whole suite re-run under a non-English, comma-decimal
locale, asserting byte-identical results.

Both backends, both platforms.
