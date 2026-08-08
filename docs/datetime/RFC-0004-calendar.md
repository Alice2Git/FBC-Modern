# RFC-0004 — Calendar arithmetic and utilities

Status: **draft** · Phase 4 · Depends on: [RFC-0001](RFC-0001-core-representation.md), [RFC-0002](RFC-0002-timespan.md)

Two distinct kinds of arithmetic, and the rule that decides what `31 Jan + 1
month` means.

## 1. Exact versus calendar arithmetic

**Exact** arithmetic adds a fixed number of ticks. It is associative,
reversible, and never surprises anyone.

**Calendar** arithmetic adds months or years — units that are not a fixed
length. It is *not* reversible and *not* associative, and pretending otherwise
is how date bugs are born.

The API keeps them visibly separate: exact arithmetic takes a `TimeSpan`,
calendar arithmetic takes a plain `long` through a differently-named method.
There is deliberately no `TimeSpan.FromMonths`.

```freebasic
' exact
declare function Add     ( byref s as TimeSpan ) as DateTime
declare function Subtract( byref s as TimeSpan ) as DateTime
declare function AddDays        ( byval n as double  ) as DateTime
declare function AddHours       ( byval n as double  ) as DateTime
declare function AddMinutes     ( byval n as double  ) as DateTime
declare function AddSeconds     ( byval n as double  ) as DateTime
declare function AddMilliseconds( byval n as double  ) as DateTime
declare function AddTicks       ( byval n as longint ) as DateTime

' calendar
declare function AddMonths( byval n as long ) as DateTime
declare function AddYears ( byval n as long ) as DateTime
```

`AddDays` takes a `double` for `AddDays( 1.5 )`, and rounds to the nearest tick
half-away-from-zero. `AddDays( 1 )` on a `DateTime` is exact tick arithmetic —
it adds exactly 86,400 seconds, and so does *not* preserve the wall-clock time
of day across a DST boundary. That is correct for a value carrying a fixed
offset, and RFC-0007 §4 covers the "same local time tomorrow" case.

Operators:

| Operator | Result |
|---|---|
| `DateTime + TimeSpan` | `DateTime` |
| `DateTime - TimeSpan` | `DateTime` |
| `DateTime - DateTime` | `TimeSpan` |
| `Instant + TimeSpan` | `Instant` |
| `Instant - TimeSpan` | `Instant` |
| `Instant - Instant` | `TimeSpan` |
| `LocalDate + n days` | via `AddDays`; `LocalDate - LocalDate → long` days |
| `= <> < > <= >=` | on each type, against its own type |

`DateTime - DateTime` where the two carry **different offsets** compares the
underlying instants, not the civil readings — `12:00+00:00` minus `13:00+01:00`
is zero. Where either operand's offset is unspecified, both are treated as
naive civil readings and the offsets are ignored. Mixing one specified and one
unspecified operand yields `Invalid`, because there is no defensible answer.

## 2. The end-of-month rule

**Normative.** `AddMonths` and `AddYears`:

1. Add `n` to the month (or year) field, carrying into the year.
2. If the resulting year is outside 1…9999, return `Invalid`.
3. If the original day-of-month exceeds the number of days in the target month,
   **clamp to the last day of the target month.**
4. The time-of-day and the offset are carried through unchanged.

```
2025-01-31 AddMonths(1)  ->  2025-02-28    (clamped)
2024-01-31 AddMonths(1)  ->  2024-02-29    (clamped, leap)
2025-03-31 AddMonths(-1) ->  2025-02-28    (clamped)
2024-02-29 AddYears(1)   ->  2025-02-28    (clamped)
2025-01-31 AddMonths(1).AddMonths(-1) -> 2025-01-28   ' NOT the original
```

That last line is the point. Clamping makes `AddMonths` lossy, and this is
documented rather than hidden. Every language in the comparison set that
implements calendar months does exactly this; the alternative (overflow into 3
March) is what nobody chose.

Clamping is *not* associative: `AddMonths(2)` and `AddMonths(1).AddMonths(1)`
differ. `AddMonths(n)` is defined as a single operation on the original
day-of-month, never as `n` repetitions.

```
2025-01-31 AddMonths(2)               ->  2025-03-31
2025-01-31 AddMonths(1).AddMonths(1)  ->  2025-02-28 -> 2025-03-28
```

The worked example must be **31 January**, not 31 December — an earlier draft of
this RFC used December, where both routes happen to land on 28 February and the
point is invisible.

A second consequence, easy to assume away when writing tests: **a month-end
source does not stay a month end.** 29 February + 1 month is 29 March, not
31 March. The rule is `min(original day, days in target month)` and nothing
stronger.

`AddYears(n)` is exactly `AddMonths(n * 12)` and the tests assert that identity
over the whole range, so the clamping is implemented once.

## 3. Calendar utilities

All of these already exist inside the rtlib as `static` helpers in
`time_core.c` and `time_week.c` and are reachable from nothing. This RFC exposes
them against the tick model.

`LocalDate` carries the same calendar surface — `AddMonths`, `AddYears`,
`StartOfMonth`, `EndOfMonth`, `IsoWeek`, `IsoWeekYear`, `Quarter`,
`IsFirstDayOfMonth`, `IsLastDayOfMonth` — and `DateTime` delegates its month
arithmetic to it, so the clamping rule is implemented exactly once. A date type
without month arithmetic would send users back to `DateTime` for the commonest
date operation there is.

```freebasic
' static, on DateTime
declare static function IsLeapYear ( byval y as long ) as boolean
declare static function DaysInMonth( byval y as long, byval mo as long ) as long
declare static function DaysInYear ( byval y as long ) as long          ' 365/366
declare static function WeeksInYear( byval y as long ) as long          ' 52/53 ISO

' instance
declare property DayOfYear ( ) as long          ' 1-366
declare property DayOfWeek ( ) as long          ' 1=Mon .. 7=Sun
declare property IsoWeek   ( ) as long          ' 1-53
declare property IsoWeekYear( ) as long         ' may differ from Year
declare property Quarter   ( ) as long          ' 1-4

declare function StartOfDay  ( ) as DateTime
declare function EndOfDay    ( ) as DateTime    ' 23:59:59.9999999
declare function StartOfMonth( ) as DateTime
declare function EndOfMonth  ( ) as DateTime
declare function StartOfYear ( ) as DateTime
declare function EndOfYear   ( ) as DateTime
declare function StartOfWeek ( byval firstDay as long = 1 ) as DateTime  ' default Mon
declare function NextWeekday ( byval dow as long ) as DateTime
declare function PrevWeekday ( byval dow as long ) as DateTime

declare property IsFirstDayOfMonth( ) as boolean
declare property IsLastDayOfMonth ( ) as boolean

' Julian day number, for astronomical and scientific interop
declare property JulianDay      ( ) as double   ' fractional, noon-based
declare property JulianDayNumber( ) as longint  ' integral
declare static function FromJulianDay( byval jd as double ) as DateTime
```

### Week numbering

`IsoWeek` is **ISO 8601** week numbering, unconditionally: weeks start Monday,
week 1 is the week containing the first Thursday of the year, and a year has 52
or 53 weeks. There is no `firstDayOfWeek` / `firstWeekOfYear` parameter pair
here — that is `datetime.bi`'s `fbFirstJan1` / `fbFirstFourDays` /
`fbFirstFullWeek` model, and it stays in `datetime.bi`.

`IsoWeekYear` is the year the ISO week belongs to, which is **not** always
`Year`. 2025-12-29 is ISO week 1 of ISO year 2026. Rendering an ISO week date
using `Year` instead of `IsoWeekYear` is the canonical bug in this area, and §5
tests for it.

### Day-of-week convention

**1 = Monday … 7 = Sunday**, per RFC-0001 §4. Restated here because this is where
it bites: it differs from `datetime.bi`'s `Weekday` (1 = Sunday) and from
AfxNova's `DayOfWeek` (0 = Sunday). Named constants are provided and should be
used in preference to literals:

```freebasic
enum DayOfWeekEnum
  dowMonday = 1, dowTuesday, dowWednesday, dowThursday, _
  dowFriday, dowSaturday, dowSunday
end enum
```

## 4. Overflow

Every function in this RFC returns `Invalid` rather than wrapping or clamping to
the range ends. `DateTime.MaxValue.AddDays(1)` is `Invalid`;
`DateTime.MinValue.AddTicks(-1)` is `Invalid`; `AddMonths(2000000)` is
`Invalid`. Detection is done on the operands before the operation, not by
inspecting the result for a sign flip.

## 5. Tests

Suite `fbc_tests.chrono.calendar`. Table-driven throughout, in the style of
`src/tests/datetime/testdate.bas`.

**End-of-month clamping** — an explicit table, at minimum:
every month-end of a leap and a non-leap year × `AddMonths` of
−13, −12, −2, −1, 0, +1, +2, +12, +13; plus 29 February +/− 1, 4, 100, 400
years. Assert the documented non-round-trip
(`2025-01-31 +1mo -1mo = 2025-01-28`) explicitly, so a future "fix" that
restores the original date fails the suite and has to argue with this file.

**`AddYears(n) = AddMonths(n*12)`** for every day of a leap year × n in
−400…400 sampled at the century boundaries.

**Exact arithmetic**
- `(a + s) - s = a` for a table of `a` and `s` including negative and zero spans.
- `(b - a) + a = b` for a table of pairs.
- `AddDays(1)` adds exactly `DT_TICKS_PER_DAY`, including across a local DST
  boundary — the assertion is that it does *not* preserve wall-clock time.
- Sub-tick rounding: `AddSeconds(0.00000005)` and `AddDays(1.0/3.0)`.

**Mixed-offset subtraction** — the three cases of §1: both specified (compares
instants), both unspecified (compares civil), one of each (`Invalid`).

**ISO week** — exhaustive over every day from 0001-01-01 to 9999-12-31, asserting:
week in 1…53; week number non-decreasing within an ISO year; each ISO year has
exactly `WeeksInYear` weeks × 7 days; and week 1 always contains that ISO year's
first Thursday. Plus a hardcoded table of the known-hard cases:
2025-12-29 → 2026-W01, 2021-01-01 → 2020-W53, 2016-01-03 → 2015-W53,
2000-01-01 → 1999-W52.

**Cross-check** the new `IsLeapYear` / `DaysInMonth` / `DayOfYear` against the
legacy `fb_hTimeLeap` / `fb_hTimeDaysInMonth` / `fb_hGetDayOfYear` over years
100–9999.

**Boundary helpers** — `StartOfDay` ≤ original ≤ `EndOfDay`;
`EndOfMonth.AddTicks(1) = StartOfMonth.AddMonths(1)`; `StartOfWeek` lands on the
requested weekday for all seven values of `firstDay`; `NextWeekday(x).DayOfWeek
= x` and the result is strictly later (7 days when already on `x`).

**Julian day** — round trip over the range; anchors: JD 2451545.0 =
2000-01-01T12:00 UTC, JD 0 = −4712-01-01T12:00 (out of range, must be `Invalid`).

**Overflow** — every function in §4's list, asserting `Invalid` and asserting the
result differs from the wrapped value.

Both backends, both platforms.
