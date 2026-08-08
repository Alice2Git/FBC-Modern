# Migration guide

`fb/chrono.bi` ships **alongside** `datetime.bi`, not instead of it. Nothing in
the legacy surface changed, so a program can adopt the new API one function at a
time, and the two meet at [`FromSerial` / `Serial`](#the-bridge).

Every name below was checked against the shipped header. Where there is no
equivalent, that is stated rather than glossed.

## The bridge

`datetime.bi` measures in **serial doubles** — days since 1899-12-30, which is
also the OLE epoch. `chrono` measures in **ticks** of 100 ns since 0001-01-01.
Two calls convert between them:

```freebasic
dim as double  legacy = DateSerial( 2025, 3, 4 )
dim as FB.DateTime modern = FB.DateTime.FromSerial( legacy )   '' legacy -> chrono
dim as double  backAgain  = modern.Serial                      '' chrono -> legacy
```

Lossy below about a millisecond: a `double` carries ~15 significant digits and a
present-day serial spends most of them on the integer part. Everything above
millisecond resolution round-trips exactly, and the suite asserts that over
1900–2100.

## `datetime.bi` → `chrono`

| Legacy | Modern | Notes |
|---|---|---|
| `DateSerial( y, m, d )` | `DateTime( y, m, d )` or `LocalDate( y, m, d )` | Legacy **normalizes** out-of-range input (month 13 rolls into next year); chrono returns `Invalid`. |
| `TimeSerial( h, m, s )` | `LocalTime( h, m, s, 0 )` | |
| `DateValue( s )` / `TimeValue( s )` | `DateTime.TryParseIso` / `TryParseExact` | Legacy guesses field order from locale. The new parsers are **strict** — see below. |
| `IsDate( s )` | `DateTime.TryParseIso( s, out )` | Returns the parsed value as well, so you don't parse twice. |
| `Now( )` | `Clock.Now( )` | Legacy is local with **no way to say so**; the new one carries its UTC offset. `Clock.UtcNow( )` gives an `Instant`. |
| `Year( serial )` | `.Year` | |
| `Month( serial )` | `.Month` | |
| `Day( serial )` | `.Day` | |
| `Hour( serial )` | `.Hour` | |
| `Minute( serial )` | `.Minute` | |
| `Second( serial )` | `.Second` | |
| `Weekday( serial )` | `.DayOfWeek` | **Different numbering.** Legacy is 1 = Sunday; chrono is ISO 1 = Monday … 7 = Sunday. Use `DT_MONDAY` … `DT_SUNDAY`. |
| `MonthName( m )` | `DateTime.MonthName( m )` | Same idea; chrono also has `MonthUName` returning `USTRING`. |
| `WeekdayName( w )` | `DateTime.WeekdayName( w )` | Note the numbering difference above. |
| `DateAdd( "yyyy", n, s )` | `.AddYears( n )` | |
| `DateAdd( "m", n, s )` | `.AddMonths( n )` | Both clamp at month end; chrono documents the rule (RFC-0004 §2). |
| `DateAdd( "d", n, s )` | `.AddDays( n )` — or `.AddCalendarDays( n )` | The two differ across a DST boundary. `AddDays` is exactly 86 400 s; `AddCalendarDays` keeps the wall-clock time. |
| `DateAdd( "h"/"n"/"s", n, s )` | `.AddHours` / `.AddMinutes` / `.AddSeconds` | |
| `DateAdd( "w", n, s )` | `.AddDays( n * 7 )` | |
| `DateAdd( "q", n, s )` | `.AddMonths( n * 3 )` | |
| `DateDiff( "d", a, b )` | `( b - a ).TotalDays` | Returns a `TimeSpan`, so every unit is available from one subtraction. |
| `DateDiff( "s", a, b )` | `( b - a ).TotalSeconds` | |
| `DatePart( "ww", s )` | `.IsoWeek` | Legacy takes `firstDayOfWeek`/`firstWeekOfYear`; chrono is **ISO 8601 only**. Pair it with `.IsoWeekYear`, which is not always `.Year`. |
| `DatePart( "y", s )` | `.DayOfYear` | |
| `DatePart( "q", s )` | `.Quarter` | |
| `FORMAT( s, mask )` | `.ToString( pattern )` | Different pattern letters — see [RFC-0006](RFC-0006-patterns.md). `.ToLocaleDateString( )` is the locale-driven equivalent. |
| `TIMER` | `Stopwatch` | **`TIMER` is the wall clock and can jump backwards.** `Stopwatch` is monotonic and is what timing code should use. |
| `DATE` / `TIME` | `Clock.Today( )` / `Clock.TimeOfDay( )` | Legacy returns preformatted strings; the new ones return values you can compute with. |
| `SETDATE` / `SETTIME` | *none* | Setting the system clock is out of scope. |
| `FileDateTime( f )` | *none yet* | Use the legacy call and `FromSerial`. |

### No legacy equivalent

These have nothing to migrate *from* — they are the gaps the work existed to close:

`TimeSpan` (any duration type at all) · `Instant` · ISO 8601 in either direction
· `Stopwatch` · `CpuClock` · explicit UTC-vs-local on a value · `LocalDate` /
`LocalTime` · overflow that returns `Invalid` instead of wrapping ·
`TimeZoneInfo.LocalOffsetAt` · the Unix / FILETIME / OLE converters.

## AfxNova → `chrono`

AfxNova is Win32-only; `chrono` is portable. Where AfxNova splits an operation
into `Local*`/`System*` pairs, chrono carries the distinction in the value.

### `CPowerTime`

| AfxNova | Modern |
|---|---|
| `Now` / `NowUTC` / `Today` | `Clock.Now( )` / `Clock.UtcNow( )` / `Clock.Today( )` |
| `Year` `Month` `Day` `Hour` `Minute` `Second` `MSecond` | `.Year` `.Month` `.Day` `.Hour` `.Minute` `.Second` `.Millisecond` |
| `DayOfWeek` | `.DayOfWeek` — **0 = Sunday becomes ISO 1 = Monday** |
| `AddYears` / `AddMonths` / `AddDays` / … | `.AddYears` / `.AddMonths` / `.AddDays` / … — **immutable**: they return a new value rather than mutating |
| `DateDiff` (broken-down Y/M/D) | *none* — subtract for a `TimeSpan`, or compare components |
| `DaysDiff` | `( a - b ).TotalDays` |
| `IsLeapYear` `DaysInMonth` `DaysInYear` `DayOfYear` | `DateTime.IsLeapYear` `DaysInMonth` `DaysInYear` · `.DayOfYear` |
| `WeekNumber` / `WeeksInYear` | `.IsoWeek` / `DateTime.WeeksInYear` |
| `WeekOne` / `WeeksInMonth` / `AstroDay` / `AstroDayOfWeek` | *none* |
| `IsFirstDayOfMonth` / `IsLastDayOfMonth` | `.IsFirstDayOfMonth` / `.IsLastDayOfMonth` |
| `ToUTC` / `ToLocalTime` | `.ToInstant( )` / `.ToLocal( )` |
| `GetAsJulianDate` / `JulianToGregorian` | `.JulianDayNumber` / `DateTime.FromJulianDay` |
| `Format` / `DateString` / `TimeString` | `.ToString( pattern )` (invariant) or `.ToLocaleDateString( )` (locale) |
| `DateSerial` property | `.Serial` |
| `GetAsFileTime` / `SetFileTime` | `.FileTime` / `DateTime.FromFileTime` |

**The one behavioural trap.** `CPowerTime.AddDays` *mutates the receiver*, so
passing one `byref` to a helper that adds a day changes the caller's value.
`chrono` types are immutable — `dt.AddDays( 3 )` on its own does nothing, and
the result must be assigned:

```freebasic
dt = dt.AddDays( 3 )        '' do
dt.AddDays( 3 )             '' silently does nothing
```

### `CTime64`

| AfxNova | Modern |
|---|---|
| `GetTime` (Unix seconds) | `Instant.UnixSeconds` |
| `CTime64( unixSeconds )` | `Instant.FromUnixSeconds( v )` |
| `GetCurrentTime` | `Clock.UtcNow( )` |
| `GetYear` … `GetDayOfWeek` | `.Year` … `.DayOfWeek` |
| `Format` / `FormatGmt` | `.ToString( pattern )` on a local / UTC value |
| `GetAsFileTime` / `GetAsSystemTime` | `.FileTime` / *no `SYSTEMTIME` converter — see RFC-0007 §4* |

### `CTimeSpan` / `CFileTimeSpan` / `COleDateTimeSpan`

All three collapse into one `TimeSpan`. `GetTotalHours` → `.TotalHours`,
`GetHours` → `.Hours`, and so on; the totals-versus-components distinction is
the same one AfxNova draws.

### `COleDateTime`

| AfxNova | Modern |
|---|---|
| `COleDateTime( dateString )` | `DateTime.TryParseIso` / `TryParseExact` — **strict**, and returns success rather than a status flag |
| `m_status` / `GetStatus` | `.IsValid` |
| `DoubleFromDate` / `DateFromDouble` | `.OleDate` / `DateTime.FromOleDate` |
| `GetAsDBTIMESTAMP` / `GetAsUDATE` | *none* — COM-specific |

### `AfxTime.inc` procedures

| AfxNova | Modern |
|---|---|
| `AfxLocalYear` / `AfxSystemYear` (and the whole `Local*`/`System*` family) | `Clock.Now( ).Year` / `Clock.UtcNow( )` then `.Year` — one clock, an explicit offset |
| `AfxTimeZoneBias` / `AfxTimeZoneDaylightBias` | `TimeZoneInfo.LocalOffset( )` — **already combined, already signed east-of-UTC** |
| `AfxTimeZoneIsDaylightSavingTime` | `TimeZoneInfo.IsDaylightSavingTime( instant )` — takes an instant, so it can answer for last July |
| `AfxTimeZoneStandardName` / `DaylightName` | `TimeZoneInfo.StandardName( )` / `DaylightName( )` |
| `AfxIsLeapYear` / `AfxDaysInMonth` / `AfxDayOfYear` / `AfxWeekNumber` / `AfxWeeksInYear` | the `DateTime` equivalents above |
| `AfxGregorianToJulian` / `AfxJulianToGregorian` | `.JulianDayNumber` / `DateTime.FromJulianDay` |
| `AfxTime64ToFileTime` and the converter family | `.FileTime`, `.UnixSeconds`, `.Serial` and their `From*` partners |
| `AfxMonthName` / `AfxShortMonthName` | `DateTime.MonthName( m )` / `MonthName( m, true )` |
| `AfxStrFromTimeInterval` | `TimeSpan.ToIsoString( )`, or `.ToString( pattern )` on a `DateTime` |

**Two deliberate divergences from AfxNova**, both because AfxNova has the bug:

1. **Day-of-week numbering.** AfxNova uses 0 = Sunday; chrono uses ISO
   1 = Monday, because the ISO week-number algorithm needs it.
2. **Historical timezone rules.** `AfxTimeZone*` reads
   `GetTimeZoneInformation`, the *static* form, which applies today's DST rule
   to every year and so misdates anything from before a rule change. chrono uses
   `GetDynamicTimeZoneInformation` + `GetTimeZoneInformationForYear`. On a North
   American machine, 20 March 2005 correctly reads as standard time.

## Parsing: the one thing that is deliberately harder

`DateValue` and `IsDate` accept a wide, undocumented set of inputs and guess
field order from the locale. `03/04/2025` is March 4th or April 3rd depending on
where the machine is.

`chrono` will not guess. Either say the format is ISO 8601:

```freebasic
if FB.DateTime.TryParseIso( s, dt ) then ...
```

or state the pattern outright:

```freebasic
if FB.DateTime.TryParseExact( s, "dd/MM/yyyy", dt ) then ...
```

`TryParse*` always writes its result, so a caller who ignores the return value
gets `Invalid` rather than a stale value. The legacy parser is untouched and
still available for input that genuinely is locale-shaped.
