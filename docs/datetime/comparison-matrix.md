# Capability comparison matrix

What every modern language offers, what FreeBASIC offers today, and what AfxNova
offers. AfxNova is included because it is the best available evidence of what a
FreeBASIC Win32 developer actually reaches for — it is a *requirements source*,
not a port target (it is Win32-only in its bones: `FILETIME`, `SYSTEMTIME`, OLE
`DATE_`, `LCID`, `VarDateFromStr`).

Legend: **Y** present · **~** partial or awkward · **·** absent.

## 1. Type taxonomy

| Capability | C++20 `<chrono>` | C# / NodaTime | java.time | Python | Rust `chrono`/`time` | Go | JS `Temporal` | VB6/VBA, QB64 | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| Instant / absolute point | `sys_time` | `DateTime(Utc)` / `Instant` | `Instant` | `datetime(tz=utc)` | `DateTime<Utc>` | `Time` | `Instant` | · | ~ `Now` (local, no tag) | Y `CTime64`, `CFileTime` |
| Naive/local date-time | `local_time` | `DateTime` / `LocalDateTime` | `LocalDateTime` | naive `datetime` | `NaiveDateTime` | ~ | `PlainDateTime` | ~ serial dbl | ~ serial dbl | Y `CPowerTime`, `COleDateTime` |
| Date only | `year_month_day` | `DateOnly` / `LocalDate` | `LocalDate` | `date` | `NaiveDate` | · | `PlainDate` | · | · | · |
| Time only | `hh_mm_ss` | `TimeOnly` / `LocalTime` | `LocalTime` | `time` | `NaiveTime` | · | `PlainTime` | · | · | · |
| Duration / span | `duration<>` | `TimeSpan` / `Duration` | `Duration` | `timedelta` | `Duration` | `Duration` | `Duration` | · | · | Y `CTimeSpan`, `CFileTimeSpan`, `COleDateTimeSpan` |
| Calendar period (Y/M/D) | `months`, `years` | `Period` | `Period` | ~ | ~ | · | `Duration` (cal.) | · | ~ `DateAdd` | ~ `CPowerTime.DateDiff` |
| Zoned date-time | `zoned_time` | `ZonedDateTime` | `ZonedDateTime` | `datetime`+`zoneinfo` | `DateTime<Tz>` | `Time`+`Location` | `ZonedDateTime` | · | · | · |
| Offset date-time | ~ | `DateTimeOffset` | `OffsetDateTime` | `datetime`+`timezone` | `DateTime<FixedOffset>` | ~ | · | · | · | · |
| Type-safe unit separation | Y (strong) | ~ | Y | ~ | Y | ~ | Y | · | · | · |

**Read:** everyone converged on *at least* {instant, local date-time, date, time,
duration}. FB has one of those five, and only as an untyped `double`. AfxNova has
three of five but no date-only or time-only type at all.

## 2. Precision and range

| | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| Resolution | ns+ | 100 ns | ns | µs | ns | ns | ns | s | **s** | 100 ns / s / ms |
| Range | unbounded | yr 1–9999 | ±1e9 yr | yr 1–9999 | ±262 kyr | ±292 yr | ±273 kyr | yr 100–9999 | ~yr 100–9999 | 1601+ / 1970+ / yr 100+ |
| Monotonic clock | `steady_clock` | `Stopwatch` | `nanoTime` | `perf_counter` | `Instant` | `Since` | · | · | **·** | **·** |
| Leap-second aware | `utc_clock` | · | · | · | ~ | · | · | · | · | · |

FB's `TIMER` is wall-clock and jumps when the system clock is adjusted; there is
no monotonic source anywhere in FB **or** AfxNova. That is the cheapest
high-value gap on the board.

## 3. Arithmetic

| Capability | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| instant ± duration | Y | Y | Y | Y | Y | Y | Y | ~ | ~ `DateAdd` | Y |
| instant − instant → duration | Y | Y | Y | Y | Y | Y | Y | ~ | ~ `DateDiff` | Y |
| duration ± duration | Y | Y | Y | Y | Y | Y | Y | · | · | Y |
| duration × / ÷ scalar | Y | Y | Y | Y | Y | · | Y | · | · | · |
| Calendar-aware `AddMonths` | Y | Y | Y | · | ~ | ~ | Y | Y | Y | Y (in-place) |
| End-of-month clamp defined | Y | Y | Y | n/a | Y | Y | Y | Y | ~ undocumented | ~ undocumented |
| Overflow is detectable | ~ | Y (throws) | Y | Y | Y (`checked_*`) | ~ | Y | · | **· wraps** | **· wraps** |
| Comparison operators | Y | Y | Y | Y | Y | Y | `compare` | ~ | ~ on dbl | Y |

## 4. Formatting

| Capability | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| ISO 8601 / RFC 3339 emit | Y | `"O"` | Y default | `isoformat` | Y | `RFC3339` | Y default | · | **·** | **·** |
| Custom pattern | Y `format` | Y | `DateTimeFormatter` | `strftime` | Y | ref layout | · | ~ `Format` | ~ `FORMAT` | Y (Win32 mask) |
| OS-locale long/short | Y | Y | Y | ~ | · | · | Y | Y | ~ `intl_*` | Y `DateString` |
| Duration formatting | Y | Y | Y | ~ | Y | Y | Y | · | · | ~ `AfxStrFromTimeInterval` |
| Deterministic, locale-free path | Y | Y | Y | Y | Y | Y | Y | · | **·** | **·** |

**The single biggest interop gap.** ISO 8601 is what JSON, HTTP, SQL, logs and
every web API speak. Neither FB nor AfxNova can emit or parse it. Every FB
program that talks to anything modern hand-rolls this today.

## 5. Parsing

| Capability | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| Strict ISO parse | Y | Y | Y | `fromisoformat` | Y | Y | Y | · | · | · |
| Strict pattern parse | Y | `ParseExact` | Y | `strptime` | Y | Y | · | · | · | · |
| Failure without exceptions | ~ | `TryParse` | · | · | `Result` | `error` | · | · | ~ `IsDate` | ~ status flag |
| Lenient/heuristic parse | · | Y | · | · | · | · | · | Y | Y `fb_hDateParse` | Y (COM) |

FB's only parser is the *lenient* one — it guesses at locale field order. That is
the opposite of what interop needs. AfxNova's only parser is
`COleDateTime`'s `VarDateFromStr`, i.e. COM, i.e. Windows-only.

## 6. Timezone handling

| Capability | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| UTC vs local is explicit in the type | Y | ~ `Kind` | Y | ~ `tzinfo` | Y | ~ | Y | · | **·** | ~ (`Local*`/`System*` fn pairs) |
| Current UTC offset | Y | Y | Y | Y | Y | Y | Y | · | · | Y `AfxTimeZoneBias` |
| Convert UTC↔local | Y | Y | Y | Y | Y | Y | Y | · | ~ | Y `ToUTC`/`ToLocalTime` |
| Named IANA zones | Y | ~ | Y | Y | ~ | Y | Y | · | · | · |
| Historical DST rules | Y | ~ | Y | Y | ~ | Y | Y | · | · | · |
| DST ambiguity/gap policy | Y | · | Y | ~ | Y | ~ | Y | · | · | · |

**Out of scope for this work** below the "named IANA zones" line — see
[rationale.md](rationale.md). Rows above it are in scope.

## 7. Calendar utilities

| Capability | C++20 | C# | java.time | Python | Rust | Go | Temporal | VB/QB | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|---|---|---|
| Leap year test | Y | Y | Y | Y | Y | · | Y | · | ~ internal | Y |
| Days in month | Y | Y | Y | Y | Y | · | Y | · | ~ internal | Y |
| Day of year | Y | Y | Y | Y | Y | Y | Y | · | ~ internal | Y |
| ISO week number | Y | Y | Y | Y | Y | Y | Y | · | ~ internal | Y |
| Weeks in year | Y | ~ | Y | · | Y | · | Y | · | ~ internal | Y |
| Day of week | Y | Y | Y | Y | Y | Y | Y | Y `Weekday` | Y | Y |
| Localized month/day names | ~ | Y | Y | Y | ~ | · | Y | Y | Y | Y |
| Julian day number | · | · | Y (`JulianFields`) | ~ | Y | · | · | · | · | Y |

FB has *all* of these already — as `static` helpers in `time_week.c` and
`time_core.c`, reachable from nothing. Exposing them is nearly free.

## 8. Interop converters

| Target | C# | java.time | Python | Rust | Go | **FB today** | **AfxNova** |
|---|---|---|---|---|---|---|---|
| Unix seconds | Y | Y | Y | Y | Y | · | Y (32-bit ⇒ **2038 bug**) |
| Unix millis / nanos | Y | Y | ~ | Y | Y | · | · |
| `struct tm` | n/a | n/a | Y | ~ | n/a | · | Y |
| Win32 `FILETIME` | Y | · | · | ~ | ~ | · | Y |
| Win32 `SYSTEMTIME` | ~ | · | · | · | · | · | Y |
| OLE `DATE` double | Y | · | · | · | · | ~ (native fmt) | Y |
| FB legacy serial double | n/a | n/a | n/a | n/a | n/a | native | Y (`COleDateTime`) |

## Summary of what FreeBASIC is missing

Ordered by how much of the matrix each one lights up:

1. No sub-second precision anywhere. Everything is `double` seconds-of-day.
2. No duration type. There is no way to *name* "three hours" in FB.
3. No ISO 8601 in either direction.
4. No monotonic clock.
5. No UTC/local distinction carried in a value.
6. No date-only or time-only type.
7. No strict parser; only a locale-guessing lenient one.
8. Calendar utilities exist but are unreachable.
9. No overflow detection — arithmetic silently wraps.
10. No interop converters to any external time representation.

See [ranked-gaps.md](ranked-gaps.md) for these re-ordered by value ÷ cost, which
is what actually drives the build order.
