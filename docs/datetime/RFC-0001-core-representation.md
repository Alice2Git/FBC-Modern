# RFC-0001 — Core representation

Status: **draft** · Phase 1–2 · Depends on: nothing · Depended on by: all others

Defines the tick model, the four core value types, the `Invalid` sentinel, and
the range and overflow rules that every other RFC inherits.

## 1. The tick

A **tick** is 100 nanoseconds. All types in this library measure in ticks and
nothing else. There is no second unit anywhere in the design.

```
1 tick          = 100 ns
1 microsecond   =           10 ticks
1 millisecond   =       10,000 ticks
1 second        =   10,000,000 ticks
1 minute        =  600,000,000 ticks
1 hour          = 36,000,000,000 ticks
1 day           = 864,000,000,000 ticks
```

A `DateTime` is an `int64` count of ticks elapsed since
`0001-01-01T00:00:00.0000000` in the **proleptic Gregorian calendar** — the
Gregorian rules projected backwards past their 1582 introduction. No Julian
calendar, no Gregorian cutover. This is what every modern library does, and it
is what ISO 8601 requires.

### Constants

```
DT_TICKS_PER_MICROSECOND =                  10
DT_TICKS_PER_MILLISECOND =              10000
DT_TICKS_PER_SECOND      =           10000000
DT_TICKS_PER_MINUTE      =          600000000
DT_TICKS_PER_HOUR        =        36000000000
DT_TICKS_PER_DAY         =       864000000000

DT_MIN_TICKS             =                  0   ' 0001-01-01T00:00:00.0000000
DT_MAX_TICKS             = 3155378975999999999   ' 9999-12-31T23:59:59.9999999
DT_INVALID_TICKS         = &h8000000000000000    ' LLONG_MIN

DT_DAYS_PER_400_YEARS    = 146097
DT_DAYS_TO_UNIX_EPOCH    = 719162               ' 0001-01-01 -> 1970-01-01
DT_TICKS_TO_UNIX_EPOCH   = 621355968000000000
DT_TICKS_TO_FILETIME     = 504911232000000000   ' 0001-01-01 -> 1601-01-01
DT_TICKS_TO_OLE_EPOCH    = 599264352000000000   ' 0001-01-01 -> 1899-12-30
```

Those last three are why this model was chosen: `FILETIME`, Unix time and OLE
`DATE` are all reachable by adding a constant (and, for Unix and OLE, one
division). See [rationale.md](rationale.md).

`DT_MAX_TICKS` is a policy limit, not a representational one — `int64` reaches
roughly year 29228. It is enforced so every in-range value has a four-digit ISO
year.

## 2. Types

Four immutable value types. Each is a FreeBASIC `type` with a single private
field and no destructor, so it passes in a register and copies trivially.

| Type | Field | Meaning |
|---|---|---|
| `DateTime` | `m_ticks as longint`, `m_offset as short` | A civil date-time plus a UTC offset in minutes. |
| `LocalDate` | `m_days as long` | A date, as days since 0001-01-01. No time, no offset. |
| `LocalTime` | `m_ticks as longint` | A time of day, 0 … `DT_TICKS_PER_DAY - 1`. No date. |
| `Instant` | `m_ticks as longint` | An absolute point on the UTC timeline. No offset field; UTC by definition. |

`TimeSpan` is specified separately in [RFC-0002](RFC-0002-timespan.md).

### 2.1 `DateTime` and its offset

`m_offset` is minutes east of UTC, range −1080 … +1080 (±18 h, the ISO 8601
limit). `m_ticks` holds the **local** civil time — the wall-clock reading — not
the UTC instant. This matches `DateTimeOffset` (C#) and `OffsetDateTime`
(java.time), and it is the representation that survives a round trip through
ISO 8601 text without losing what the writer meant.

Three offset states are distinguished:

| `m_offset` | Meaning | ISO 8601 suffix |
|---|---|---|
| `0` with the UTC flag set | Explicitly UTC | `Z` |
| any value, flag clear | A known fixed offset | `+05:30` |
| `DT_OFFSET_UNSPECIFIED` (`&h7FFF`) | Naive; no offset known | *(none)* |

`DT_OFFSET_UNSPECIFIED` is what a `DateTime` constructed from bare components
carries. It means "the caller did not say", and it is a *distinct* state from
UTC — conflating them is the `DateTimeKind.Unspecified` mistake that C# is stuck
with. Converting an unspecified `DateTime` to an `Instant` requires an explicit
call naming an interpretation (`AssumeUtc` or `AssumeLocal`); it never happens
implicitly.

The UTC flag is the sign bit of a distinguished encoding rather than a separate
field: `m_offset = 0` means UTC, and a genuine zero-offset-but-not-UTC value is
not representable and not needed (`+00:00` and `Z` denote the same offset).

### 2.2 `Instant`

`Instant` is the type for "when did this happen". It has no offset because an
absolute point does not have one. Timestamps, log lines, expiry times, and
anything compared across machines should be `Instant`.

`Instant` ↔ `DateTime` conversion is always explicit and always names a zone:
`DateTime.FromInstant( inst, offMin )` one way, `dt.ToInstant( )` the other.
(`ToLocal` needs the OS and arrives in [RFC-0007](RFC-0007-zones-locale-interop.md).)
See §4 on why the first is a `DateTime` static rather than an `Instant` member.

### 2.3 `LocalDate` / `LocalTime`

Separate types so that "2025-03-04" and "14:30" cannot be accidentally compared,
subtracted, or fed to a function expecting the other. `LocalDate` in particular
eliminates the whole midnight-versus-noon bug class that a date-shaped
`DateTime` invites.

`m_days` is a `long`; range 0 … 3652058 fits comfortably.

## 3. The `Invalid` sentinel

Every type has a distinguished invalid value and an `IsValid` property.

| Type | Invalid encoding |
|---|---|
| `DateTime` | `m_ticks = DT_INVALID_TICKS` |
| `Instant` | `m_ticks = DT_INVALID_TICKS` |
| `LocalTime` | `m_ticks = DT_INVALID_TICKS` |
| `LocalDate` | `m_days = &h80000000` |

Rules, normative:

1. Any constructor given out-of-range components yields `Invalid`. It does not
   clamp, does not normalize, and does not raise an `err()`.
2. Any arithmetic that would leave the range `DT_MIN_TICKS … DT_MAX_TICKS`
   yields `Invalid`. **Arithmetic never wraps.** This is the single most
   important correctness rule in the library; FB and AfxNova both wrap today.
3. `Invalid` is absorbing: any operation with an `Invalid` operand yields
   `Invalid`.
4. Comparison of an `Invalid` value with anything yields `false`, including
   `Invalid = Invalid`. `IsValid` is the only correct test. (This mirrors IEEE
   NaN, and for the same reason: an equality that succeeds would let invalid
   values silently pass validation.)
5. Formatting an `Invalid` value yields the empty string.

Rule 4 is deliberate and will surprise someone. It is written down here so the
tests can assert it and the docs can warn about it.

## 4. Public surface

Illustrative FreeBASIC. Names are normative; exact `byref`/`byval` decoration is
settled in implementation and must match this file when it lands.

```freebasic
type DateTime
  ' -- construction -------------------------------------------------
  declare constructor( )                                  ' Invalid
  declare constructor( byval y as long, byval mo as long, byval d as long )
  declare constructor( byval y as long, byval mo as long, byval d as long, _
                       byval h as long, byval mi as long, byval s as long, _
                       byval ms as long = 0 )
  declare static function FromTicks( byval t as longint ) as DateTime
  declare static function FromDate( byref d as LocalDate ) as DateTime
  declare static function FromDateTime( byref d as LocalDate, byref t as LocalTime ) as DateTime

  ' -- state --------------------------------------------------------
  declare property IsValid( ) as boolean
  declare property Ticks( ) as longint
  declare property OffsetMinutes( ) as short
  declare property HasOffset( ) as boolean
  declare property IsUtc( ) as boolean

  ' -- components ---------------------------------------------------
  declare property Year( ) as long
  declare property Month( ) as long          ' 1-12
  declare property Day( ) as long            ' 1-31
  declare property Hour( ) as long           ' 0-23
  declare property Minute( ) as long         ' 0-59
  declare property Second( ) as long         ' 0-59
  declare property Millisecond( ) as long    ' 0-999
  declare property Microsecond( ) as long    ' 0-999999
  declare property TickOfDay( ) as longint
  declare property DayOfWeek( ) as long      ' 1=Mon .. 7=Sun  (ISO 8601)
  declare property DayOfYear( ) as long      ' 1-366

  ' -- decomposition ------------------------------------------------
  declare function GetDate( ) as LocalDate
  declare function GetTimeOfDay( ) as LocalTime

  ' -- offset -------------------------------------------------------
  declare function WithOffset( byval minutes as short ) as DateTime  ' reinterpret
  declare function ToOffset( byval minutes as short ) as DateTime    ' convert
  declare function AssumeUtc( ) as Instant
  declare function AssumeLocal( ) as Instant   ' RFC-0007; needs the OS
  declare function ToInstant( ) as Instant     ' Invalid if offset unspecified

  ' The Instant -> DateTime direction. See the note below on why it is a
  ' static here rather than a member on Instant.
  declare static function FromInstant( byref i as Instant, _
                                       byval offMin as short ) as DateTime
end type
```

Arithmetic (`Add*`, `Subtract`) is specified in
[RFC-0004](RFC-0004-calendar.md); formatting and parsing in
[RFC-0005](RFC-0005-iso8601.md) and [RFC-0006](RFC-0006-patterns.md); offset
resolution and interop in [RFC-0007](RFC-0007-zones-locale-interop.md).

**Type order is load-bearing (phase 2 finding).** FreeBASIC cannot
forward-declare a UDT well enough to return one *by value*, so a type may only
return types defined above it. The declaration order is therefore `TimeSpan`,
`LocalDate`, `LocalTime`, `Instant`, `DateTime`. That is why the Instant →
DateTime conversion is spelled `DateTime.FromInstant( i, offMin )` rather than
`Instant.ToUtc( )` / `Instant.ToOffset( )` as an earlier draft of this section
had it; the reverse direction, `DateTime.ToInstant( )`, is a plain member
because `Instant` is already complete by that point.

**Naming.** The types live in `namespace FB` — `FB.DateTime`, `FB.TimeSpan` —
matching `fb/array.bi`, `fb/map.bi`, `fb/set.bi` and `fb/string.bi`, the
convention this tree adopted for new library types. The header is
`src/inc/fb/chrono.bi`. `CompareTo` returns `-2` when either operand is
`Invalid`, which is "not comparable" rather than an ordering.

`DayOfWeek` is **1 = Monday through 7 = Sunday**, per ISO 8601. This
deliberately differs from `datetime.bi`'s `Weekday` (1 = Sunday) and from
AfxNova's `DayOfWeek` (0 = Sunday). Two neighbouring conventions is one too
many, and the ISO one is the one the ISO week-number algorithm needs. RFC-0004
restates this where it bites.

## 5. The C kernel

Phase 1 delivers `src/src/rtlib/dt_core.c` and `src/src/rtlib/fb_chrono.h`,
the latter included from `fb.h` immediately after `fb_datetime.h`. Pure
functions: no OS calls, no allocation, no locale, no globals. Everything above
is a thin `alias` onto these.

The C-side constants carry an `FB_DT_` prefix (`FB_DT_TICKS_PER_DAY`,
`FB_DT_MAX_TICKS`, `FB_DT_INVALID_TICKS`, …) to match rtlib's macro
convention; the `DT_`-prefixed names used in §1 above are the FreeBASIC-side
spelling that phase 2 exposes in `chrono.bi`. `long long` is used rather than a
fixed-width typedef, matching the rest of the rtlib.

```c
/* civil <-> tick.  Returns 0 on success; non-zero on out-of-range, in which
   case *out_ticks is set to FB_DT_INVALID_TICKS. */
int  fb_DtFromCivil ( int year, int month, int day, int hour, int minute,
                      int second, long long subsecond_ticks,
                      long long *out_ticks );
void fb_DtToCivil   ( long long ticks, int *year, int *month, int *day,
                      int *hour, int *minute, int *second,
                      long long *subsecond_ticks );

/* the two primitives everything else is built on */
int  fb_DtDaysFromCivil ( int year, int month, int day );  /* days since 0001-01-01 */
void fb_DtCivilFromDays ( int days, int *year, int *month, int *day );

int  fb_DtIsLeapYear    ( int year );
int  fb_DtDaysInMonth   ( int year, int month );
int  fb_DtDaysInYear    ( int year );
int  fb_DtDayOfWeek     ( int days );      /* 1=Mon .. 7=Sun */
int  fb_DtDayOfYear     ( int year, int month, int day );
int  fb_DtIsoWeek       ( int year, int month, int day, int *out_iso_year );
int  fb_DtIsoWeeksInYear( int year );

/* validation, split out so phase 2 can reuse it without composing ticks */
int  fb_DtIsValidDate   ( int year, int month, int day );
int  fb_DtIsValidTime   ( int hour, int minute, int second,
                          long long subsecond_ticks );
int  fb_DtIsValidTicks  ( long long ticks );
```

Argument order is `(year, month, day)` throughout — note this is the reverse of
the legacy `fb_hTimeDaysInMonth( month, year )`, which is a real trap when
cross-checking the two.

`fb_DtDaysFromCivil` / `fb_DtCivilFromDays` use the closed-form
days-from-civil algorithm (shift the year to start in March so the leap day
lands last, then arithmetic on the 146097-day 400-year cycle). **Not** a lookup
table and **not** a loop over years — the closed form is branch-light, exact over
the whole range, and is what makes the exhaustive round-trip test in §6 cheap
enough to run every build.

Existing helpers in `time_core.c` and `time_week.c` (`fb_hTimeLeap`,
`fb_hTimeDaysInMonth`, `fb_hGetWeekOfYear`) are **not** reused — they operate on
the legacy serial-double model and are `static`. They are, however, the
cross-check: phase 1 tests assert the new kernel agrees with them over the range
where both are defined.

## 6. Tests

Suite `fbc_tests.chrono.core`, plus a C-level test in the style of the existing
`ustr_*_test.c`.

Mandatory:

- **Exhaustive civil↔day round trip.** Every day from 0001-01-01 to 9999-12-31
  (3,652,059 iterations): `fb_DtCivilFromDays( fb_DtDaysFromCivil( y,m,d ) )`
  must return `(y,m,d)`, and the day counter must increase by exactly 1 each
  step. This single test subsumes most leap-year, month-length and
  century-rule testing.
- **Day-of-week continuity** across the same range: the value must cycle 1…7
  without a break, and known anchors must match (2000-01-01 = Saturday = 6,
  1970-01-01 = Thursday = 4, 0001-01-01 = Monday = 1).
- **Tick round trip** at every boundary: `DT_MIN_TICKS`, `DT_MAX_TICKS`, each
  ±1, every month end, every 29 February in range, and 1000 pseudo-random
  in-range values from a fixed seed.
- **Out-of-range construction** → `Invalid`, one case per component:
  month 0, month 13, day 0, day 32, 30 February, 31 April, 29 February 1900,
  29 February 2100, year 0, year 10000, hour 24, minute 60, second 60.
  (29 February 2000 must *succeed* — it is the century rule's positive case.)
- **`Invalid` semantics**, all five rules of §3 asserted individually,
  including that `Invalid = Invalid` is `false`.
- **Cross-check against the legacy kernel** for leap year and days-in-month over
  years 100–9999.
- **Offset states**: unspecified ≠ UTC; `ToInstant` on an unspecified value is
  `Invalid`; `AssumeUtc` and `AssumeLocal` differ by exactly the local offset.

Run under the default backend and `GEN=gas64`, on Windows and Linux.
