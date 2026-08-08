# RFC-0007 — Offsets, locale formatting, interop

Status: **draft** · Phase 7 · Depends on: [RFC-0001](RFC-0001-core-representation.md) … [RFC-0006](RFC-0006-patterns.md)

The three things that must touch the operating system, kept together and kept
last so everything above them stays pure and portable.

## 1. The timezone model

**In scope:** UTC, the OS local zone, explicit fixed offsets.
**Out of scope:** the IANA tz database, named zones, historical DST rules,
DST-ambiguity resolution policies. See [rationale.md](rationale.md).

The OS knows the user's zone and its current rules and keeps them updated. That
covers what a desktop application does. Nothing specified here forecloses a
future `ZonedDateTime` — `DateTime` already carries an offset field.

```freebasic
namespace TimeZoneInfo        ' a namespace, not a TYPE: FreeBASIC rejects a
  declare function LocalOffset( ) as short          ' TYPE with no data members
  declare function LocalOffsetAt( byref i as Instant ) as short
  declare function IsDaylightSavingTime( byref i as Instant ) as boolean
  declare function StandardName( ) as string
  declare function DaylightName ( ) as string
  declare function SupportsDaylightSavingTime( ) as boolean
end namespace
```

`LocalOffsetAt` — the offset **at a given instant**, not the offset right now.
Converting a timestamp from last July using January's offset is the single most
common timezone bug, and an API that only offers "the current offset" makes it
the path of least resistance.

Backends:

| | Windows | Linux |
|---|---|---|
| Offset at instant | `SystemTimeToTzSpecificLocalTimeEx` with `GetDynamicTimeZoneInformation` | `localtime_r` → `tm_gmtoff` |
| DST flag | `TIME_ZONE_ID_DAYLIGHT` from `GetTimeZoneInformationForYear` | `tm_isdst` |
| Names | `DynamicTimeZoneInformation.StandardName` / `.DaylightName` (UTF-16) | `tzname[0]` / `tzname[1]` |

`GetDynamicTimeZoneInformation` rather than `GetTimeZoneInformation`, because
only the dynamic form knows historical rules — the static one applies today's
DST rule to every year, which silently misdates anything from before a rule
change. AfxNova's `AfxTimeZone*` family uses the static form and inherits that
bug; this is a deliberate divergence from the requirements source.

On Linux, `localtime_r` reads `TZ`/`/etc/localtime` and is where glibc consults
the system tzdb. That gets historical correctness for free without this library
shipping or maintaining a database.

Both backends are called through a thread-safe wrapper: `localtime_r` (not
`localtime`), and the Windows calls take no global state. `tzname` access is
guarded, since it is process-global.

### Local↔UTC conversion

As in RFC-0001 §4, the Instant → DateTime direction is spelled
`DateTime.FromInstant( i, offMin )` — FreeBASIC cannot forward-declare a UDT
return type, so `Instant` cannot have members returning `DateTime`. `ToLocal`
is therefore a `DateTime` member that re-resolves the offset for its own
instant.

```freebasic
' on DateTime
declare function ToLocal ( ) as DateTime      ' offset re-resolved for that instant
declare function AssumeUtc  ( ) as Instant
declare function AssumeLocal( ) as Instant    ' see ambiguity note
declare function ToInstant  ( ) as Instant    ' Invalid if offset unspecified
declare function ToOffset   ( byval minutes as short ) as DateTime   ' converts
declare function WithOffset ( byval minutes as short ) as DateTime   ' reinterprets
```

`ToOffset` and `WithOffset` are the pair people confuse, so: `ToOffset` keeps the
instant and changes the wall reading; `WithOffset` keeps the wall reading and
changes the instant. Both are needed and neither is a safe default, which is why
neither is implicit.

**DST ambiguity.** `AssumeLocal` on a civil time inside a fall-back hour names
two instants, and inside a spring-forward gap names none. Without tzdb there is
no machinery to model this properly, so the documented behaviour is: **the OS
answer is taken as given** — Windows resolves ambiguity to standard time, glibc
resolves per `tm_isdst = -1`. This is a real limitation, it is written down
here, and it is the strongest argument for a future tzdb phase. Programs that
care should carry `Instant` and never round-trip through a naive `DateTime`.

## 2. Preserving wall-clock time across DST

RFC-0004 §1 notes that `AddDays(1)` is exact tick arithmetic and therefore does
*not* preserve the time of day across a DST boundary. The calendar-preserving
variants live here, because they need the OS:

```freebasic
declare function AddCalendarDays  ( byval n as long ) as DateTime
declare function AddCalendarMonths( byval n as long ) as DateTime
declare function AddCalendarYears ( byval n as long ) as DateTime
```

These operate on the civil fields, then re-resolve the offset for the resulting
local time. "Same time tomorrow" is `AddCalendarDays(1)`; "24 hours from now" is
`AddDays(1)`. They differ twice a year and the names say which is which.

## 3. OS-locale formatting

Parity with AfxNova's `DateString` / `TimeString` / `MonthString`.

```freebasic
declare function ToLocaleDateString( byval style as LocaleStyle = lsShort ) as string
declare function ToLocaleTimeString( byval style as LocaleStyle = lsShort ) as string
declare function ToLocaleString    ( byval style as LocaleStyle = lsShort ) as string

declare static function MonthName  ( byval mo as long, byval abbreviated as boolean = false ) as string
declare static function WeekdayName( byval dow as long, byval abbreviated as boolean = false ) as string

enum LocaleStyle
  lsShort, lsLong, lsFull
end enum
```

| | Windows | Linux |
|---|---|---|
| Date | `GetDateFormatEx` | `nl_langinfo( D_FMT / D_T_FMT )` + `strftime` |
| Time | `GetTimeFormatEx` | `nl_langinfo( T_FMT )` + `strftime` |
| Names | `GetLocaleInfoEx( LOCALE_SMONTHNAME* )` | `nl_langinfo( MON_1… / DAY_1… )` |

Output is UTF-8 `string`. On Windows the API is UTF-16 and is converted at the
boundary; on Linux the locale's own encoding is converted to UTF-8. Non-ASCII
output is expected and is the reason phase 8's `USTRING` overloads exist.

**The `USTRING` surface (phase 8).** `fb/string.bi` sets the tree's rule: the
*input* type decides the output type, and a function cannot return the type it
was handed. Applied here:

- Anything that **takes** text overloads on `USTRING` and returns `USTRING` —
  `ToString( pattern )`, `TryFormat`, `TryParseIso`, `TryParse`, `ParseIso`,
  `TryParseExact`, `ParseExact`, on every type that has them.
- Anything that takes **no** text cannot overload on return type alone, so it
  carries a `U`: `ToIsoUString`, `ToLocaleDateUString`, `ToLocaleTimeUString`,
  `ToLocaleUString`, `MonthUName`, `WeekdayUName`.

Every one is a boundary conversion and nothing more: FreeBASIC decodes
`STRING` → `USTRING` as UTF-8 and encodes back the same way, and the C layer
already emits UTF-8 on both platforms, so the round trip is exact (verified:
a 5-byte UTF-8 sequence becomes 2 code units and returns byte-identical).

ISO 8601 and the pattern formatter are ASCII by construction, so their
`USTRING` forms exist for uniformity rather than need — **the locale family is
the only part of this library where `USTRING` genuinely earns its keep**, which
is why phase 8 waited for a frozen `STRING` surface rather than shadowing a
moving target. Note a `USTRING` length counts UTF-16 code units, so it is at
most the UTF-8 byte count and often less; the tests assert that direction.

**Honest limitation, stated here so the tests do not pretend otherwise:** this
output is whatever the machine's locale says and **cannot be asserted by exact
string**. Its tests (§6) check non-emptiness, plausible length, ASCII-vs-UTF-8
validity, and round-trip through the locale's own parse where one exists — and
nothing more. Any test claiming to verify locale-formatted output byte-for-byte
is either locale-pinned or lying.

This is precisely why RFC-0006's pattern formatter uses invariant English: it is
the one that can be tested, and it is the one that should be used for anything
written to a file.

## 4. Interop converters

The bridge that lets existing code migrate a function at a time.

```freebasic
' Unix
declare static function FromUnixSeconds     ( byval s  as longint ) as Instant
declare static function FromUnixMilliseconds( byval ms as longint ) as Instant
declare static function FromUnixMicroseconds( byval us as longint ) as Instant
declare property UnixSeconds     ( ) as longint      ' floor toward -inf
declare property UnixMilliseconds( ) as longint
declare property UnixMicroseconds( ) as longint

' FreeBASIC legacy serial double  --  the migration path
declare static function FromSerial( byval d as double ) as DateTime
declare property Serial( ) as double

' Windows-shaped, but pure arithmetic, so NOT behind an #ifdef
declare static function FromFileTime  ( byval ft as longint ) as DateTime
declare property FileTime( ) as longint
declare static function FromOleDate   ( byval d  as double    ) as DateTime
declare property FileTime  ( ) as ulongint
declare property SystemTime( ) as SYSTEMTIME
declare property OleDate   ( ) as double
```

`FromSerial` / `Serial` are the important pair — they convert to and from
`inc/datetime.bi`'s representation, so a program can adopt the new API in one
function while the rest keeps using `DateSerial` and `DateAdd`. Serial doubles
carry roughly millisecond precision at present-day magnitudes, so the conversion
is documented as **lossy in the sub-millisecond digits** and rounds to the
nearest tick.

Conversions that overflow the target representation yield `Invalid` (into the
library) or are documented as saturating (out of it, where the target has no
invalid value — `UnixSeconds` of an `Invalid` instant is `LLONG_MIN`).

All conversion constants are in RFC-0001 §1. `FileTime` in particular is a
single addition, with no scaling and no rounding.

### Not shipped in phase 7

`FromTimeT`, `FromTm` / `ToTm`, and `FromSystemTime` / `SystemTime` are **not
implemented**, and this is recorded rather than quietly dropped:

- `FromTimeT` is exactly `FromUnixSeconds`, so it would be a synonym.
- `tm` and `SYSTEMTIME` are struct-interop conveniences whose whole content is
  the components this API already exposes — a caller who needs one can fill it
  from `Year`/`Month`/`Day`/… in three lines, and making the library depend on
  `crt/time.bi` or `windows.bi` to save those three lines is a bad trade for a
  header that is otherwise dependency-free.
- `FromFileTime` / `FileTime` **are** shipped, and are *not* behind an `#ifdef`:
  they are pure arithmetic on a tick constant, so they work and are testable on
  Linux too. A program using them is knowingly interoperating with a Windows
  representation, not requiring Windows.

`FileTime` cannot represent an instant before 1601-01-01 and returns a negative
value there; `FromFileTime` rejects negatives as `Invalid`.

## 5. Windows-only surface

`FromFileTime`, `FromSystemTime`, `FromOleDate` and their inverses are inside
`#ifdef __FB_WIN32__`. Everything else in this library compiles and passes on
both platforms. A program using the Win32 converters is knowingly
Windows-specific; a program using anything else is not.

## 6. Tests

Suite `fbc_tests.chrono.zones`, `…interop`, `…locale`.

**A property that is NOT portably testable.** The dynamic-vs-static zone API
requirement of §1 cannot be killed by an automated test. The discriminator is
that North America moved the DST start from April to mid-March in 2007, so on
an affected zone 20 March 2005 is standard time and 20 March 2025 is daylight
time. A static-rules implementation makes the two *equal* — and a test guarded
on "are they different?" then takes its skip branch and passes. There is no
portable way to know independently whether a given machine's zone had a rule
change, so the suite emits a **warning**, not a silent skip, and the property is
verified by manual inspection. Observed on a Newfoundland machine with the
dynamic API in place: 2005-03-20 → −210 (standard), 2025-03-20 → −150
(daylight), 2025-01-15 → −210. With the static API both March values read −150.

**Offsets**
- `LocalOffset` in −1080…+1080 and a whole number of minutes.
- `LocalOffsetAt` for a January instant and a July instant: on a DST-observing
  machine they differ by exactly `SupportsDaylightSavingTime`'s bias; on a
  non-DST machine they are equal. The test reads the machine's own answer for
  which case applies rather than assuming a zone.
- `Instant.ToLocal().ToInstant()` is the identity for 10,000 fixed-seed
  instants. This is the round-trip that catches an offset sign error, and it
  holds even across DST because `ToLocal` records the offset it used.
- `ToOffset` preserves the instant and changes the wall reading; `WithOffset`
  does the opposite. Asserted as a pair on the same value, which is the only way
  to catch them being implemented identically.
- `AddCalendarDays(1)` and `AddDays(1)` agree away from a DST boundary and
  differ across one, on a DST-observing machine. **Asserting the hour is not
  enough**: a `DateTime` carries a *fixed* offset, so plain `AddDays` preserves
  the wall-clock hour too and the two look identical. What actually
  distinguishes them is that `AddCalendarDays` **re-resolves the offset** — so
  assert `OffsetMinutes` changed, and that the elapsed real time is *not* 24 h.
  Mutation-verified: deleting the re-resolution fails 4 assertions; deleting it
  and asserting only the hour fails none.

**Interop**
- Round trip through every converter for fixed-seed values spanning the whole
  tick range. **`FILETIME` cannot represent an instant before its 1601 epoch**,
  so the test round-trips above `DT_TICKS_TO_FILETIME` and asserts `Invalid`
  below it, rather than skipping — the boundary itself is then tested too.
- Anchors, hardcoded, one per representation — these catch an epoch constant off
  by a century, which relative tests never do:
  Unix 0 = 1970-01-01T00:00:00Z; Unix 1000000000 = 2001-09-09T01:46:40Z;
  `FILETIME` 0 = 1601-01-01T00:00:00Z; OLE 0.0 = 1899-12-30T00:00:00;
  OLE 1.0 = 1899-12-31; serial double round-trip against a value produced by
  `datetime.bi`'s own `DateSerial`.
- Negative Unix times (pre-1970) floor toward −infinity, not toward zero.
- Overflow: `FromUnixSeconds( LLONG_MAX )` → `Invalid`.
- **Cross-check against the legacy API**: for 1000 dates, `FromSerial( DateSerial(y,m,d) )`
  has the same year/month/day as the inputs, and `Serial` fed back to
  `datetime.bi`'s `Year`/`Month`/`Day` agrees. This is the assertion that the
  migration path actually works.

**Locale** — invariants only, and the suite says so in a comment:
non-empty; valid UTF-8; length within plausible bounds; `lsLong` output at least
as long as `lsShort`; all twelve `MonthName` values distinct; all seven
`WeekdayName` values distinct; abbreviated no longer than full. **No exact
string assertions.** The suite additionally runs under two different locales and
asserts only that the results differ for at least one non-English locale —
i.e. that the locale is actually being consulted.

Both backends, both platforms. Where a machine's zone makes a DST assertion
inapplicable, the test skips and **logs the skip** rather than passing silently.
