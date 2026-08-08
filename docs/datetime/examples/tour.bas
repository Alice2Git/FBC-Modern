'' fb/chrono.bi -- a tour of the library.
''
'' Build (from the repo root):
''   src/bin/fbc.exe -i src/inc docs/datetime/examples/tour.bas
''
'' Every line here is executed by the doc build, so nothing in it can drift
'' away from what the library actually does.

#include once "fb/chrono.bi"

using FB

print "=== construction and components ==="
dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )
print "  " & d.ToIsoString( )
print "  year="; d.Year; " month="; d.Month; " day="; d.Day;
print " hour="; d.Hour; " minute="; d.Minute; " second="; d.Second
print "  day of week="; d.DayOfWeek; " (1=Mon)  day of year="; d.DayOfYear;
print "  ISO week="; d.IsoWeek; " quarter="; d.Quarter

print
print "=== out-of-range construction yields Invalid, it does not throw ==="
dim as DateTime bad = DateTime( 2025, 2, 30 )
print "  2025-02-30 valid = "; bad.IsValid
print "  2024-02-29 valid = "; DateTime( 2024, 2, 29 ).IsValid
'' BEWARE: comparing Invalid with anything is false, including with itself
print "  Invalid = Invalid -> "; ( DateTime.Invalid = DateTime.Invalid ); " (use IsValid)"

print
print "=== immutable: the receiver is never modified ==="
dim as DateTime later = d.AddDays( 3 )
print "  d      = " & d.ToIsoString( )
print "  +3days = " & later.ToIsoString( )

print
print "=== durations ==="
dim as TimeSpan gap = later - d
print "  gap = " & gap.ToIsoString( ) & "   totalHours="; gap.TotalHours
dim as TimeSpan mix = TimeSpan( 1, 2, 3, 4, 500 )
print "  " & mix.ToIsoString( ) & " -> days="; mix.Days; " hours="; mix.Hours;
print " minutes="; mix.Minutes; " totalHours="; mix.TotalHours
'' components of a negative span are ALL negative
dim as TimeSpan neg = TimeSpan.FromHours( -1.5 )
print "  -1.5h -> hours="; neg.Hours; " minutes="; neg.Minutes

print
print "=== arithmetic never wraps ==="
print "  MaxValue + 1 tick valid = "; DateTime.MaxValue.AddTicks( 1 ).IsValid
print "  MinValue - 1 day  valid = "; DateTime.MinValue.AddDays( -1 ).IsValid

print
print "=== calendar arithmetic clamps at month end, and is lossy ==="
print "  2025-01-31 +1mo   = " & DateTime( 2025, 1, 31 ).AddMonths( 1 ).ToIsoString( )
print "  2024-01-31 +1mo   = " & DateTime( 2024, 1, 31 ).AddMonths( 1 ).ToIsoString( )
print "  ...then -1mo      = " & DateTime( 2025, 1, 31 ).AddMonths( 1 ).AddMonths( -1 ).ToIsoString( )
print "  (+2mo) != (+1+1)  : " & DateTime( 2025, 1, 31 ).AddMonths( 2 ).ToIsoString( ) & _
      "  vs  " & DateTime( 2025, 1, 31 ).AddMonths( 1 ).AddMonths( 1 ).ToIsoString( )

print
print "=== ISO 8601 round trip ==="
dim as DateTime off = d.WithOffset( 330 )
print "  offset  : " & off.ToIsoString( )
print "  UTC     : " & d.WithOffset( 0 ).ToIsoString( )
print "  naive   : " & d.ToIsoString( )
dim as DateTime parsed
if DateTime.TryParseIso( "2025-03-04T14:30:05.1230000+05:30", parsed ) then
	print "  parsed back, same ticks = "; ( parsed.Ticks = off.Ticks )
end if
'' the parser is strict, and always writes its result
print "  '03/04/2025' parses = "; DateTime.TryParseIso( "03/04/2025", parsed );
print "  (ambiguous input is refused, not guessed)"

print
print "=== custom patterns: invariant, safe to write to a file ==="
print "  " & d.ToString( "yyyy-MM-dd HH:mm:ss" )
print "  " & d.ToString( "dddd, dd MMMM yyyy" )
print "  " & d.ToString( "ddd MMM d yyyy h:mm tt" )
print "  RFC 1123: " & off.ToString( "R" )

print
print "=== the wall clock carries its offset ==="
dim as DateTime nowLocal = Clock.Now( )
print "  local : " & nowLocal.ToIsoString( )
print "  UTC   : " & Clock.UtcNow( ).ToIsoString( )
print "  offset minutes ="; nowLocal.OffsetMinutes; "  zone = " & TimeZoneInfo.StandardName( )

print
print "=== Stopwatch is monotonic; TIMER is not ==="
dim as TimeSpan cpu0 = CpuClock.ProcessTime( )
dim as Stopwatch sw = Stopwatch.StartNew( )
dim as double acc = 0
'' enough work to exceed the CPU clock's ~15.6 ms granularity on Windows
for i as integer = 1 to 60000000
	acc += i * 0.5
next
sw.Stop_( )
dim as TimeSpan cpu1 = CpuClock.ProcessTime( )
print "  elapsed     = " & sw.Elapsed.ToIsoString( ) & "  (" & sw.ElapsedMilliseconds & " ms)"
print "  CPU burned  = " & ( cpu1 - cpu0 ).ToIsoString( )
print "  monotonic: never jumps, unlike TIMER across an NTP correction"
if acc = 0 then print "  (unreachable)"

print
print "=== interop ==="
print "  unix 0        = " & Instant.FromUnixSeconds( 0 ).ToIsoString( )
print "  unix 1e9      = " & Instant.FromUnixSeconds( 1000000000 ).ToIsoString( )
print "  FILETIME 0    = " & DateTime.FromFileTime( 0 ).ToIsoString( )
print "  OLE 0.0       = " & DateTime.FromOleDate( 0.0 ).ToIsoString( )
print "  legacy serial = "; DateTime( 2025, 3, 4 ).Serial
