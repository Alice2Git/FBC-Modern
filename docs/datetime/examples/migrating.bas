'' Migrating from datetime.bi to fb/chrono.bi, one function at a time.
''
'' Build (from the repo root):
''   src/bin/fbc.exe -i src/inc docs/datetime/examples/migrating.bas
''
'' The point of this file: BOTH headers are included, both APIs are live, and
'' values cross between them.  That is the intended migration path -- there is
'' no flag day.

#include once "vbcompat.bi"        '' the legacy surface
#include once "fb/chrono.bi"       '' the new one

using FB

print "=== the bridge: serial double <-> ticks ==="
dim as double legacy = DateSerial( 2025, 3, 4 )
dim as DateTime modern = DateTime.FromSerial( legacy )
print "  legacy DateSerial( 2025, 3, 4 ) = "; legacy
print "  chrono  reads it as             = " & modern.ToIsoString( )
print "  and back again                  = "; modern.Serial
print "  legacy accessors still agree    = "; Year( modern.Serial ); Month( modern.Serial ); Day( modern.Serial )

print
print "=== the same instant, both ways ==="
dim as double legacyNow = Now( )
dim as DateTime chronoNow = Clock.Now( )
print "  legacy Now( ) is LOCAL with no way to say so:"
print "    "; Year( legacyNow ); Month( legacyNow ); Day( legacyNow ); Hour( legacyNow ); Minute( legacyNow )
print "  chrono carries the offset in the value:"
print "    " & chronoNow.ToIsoString( )

print
print "=== weekday numbering DIFFERS -- the one trap ==="
dim as double s = DateSerial( 2025, 3, 4 )       '' a Tuesday
print "  legacy Weekday( ) = "; Weekday( s ); "  (1 = Sunday, so Tuesday is 3)"
print "  chrono .DayOfWeek = "; DateTime( 2025, 3, 4 ).DayOfWeek; "  (ISO 1 = Monday, so Tuesday is 2)"
print "  use the DT_* constants: DT_TUESDAY = "; DT_TUESDAY

print
print "=== month arithmetic: same clamping, clearer name ==="
print "  legacy DateAdd( ""m"", 1, 31 Jan ) -> ";
dim as double la = DateAdd( "m", 1, DateSerial( 2025, 1, 31 ) )
print Year( la ); Month( la ); Day( la )
print "  chrono .AddMonths( 1 )            -> " & _
      DateTime( 2025, 1, 31 ).AddMonths( 1 ).ToIsoString( )

print
print "=== differences: one subtraction, every unit ==="
dim as double a = DateSerial( 2025, 1, 1 ), b = DateSerial( 2025, 3, 4 )
print "  legacy needs a call per unit:"
print "    days    = "; DateDiff( "d", a, b )
print "    hours   = "; DateDiff( "h", a, b )
dim as TimeSpan gap = DateTime( 2025, 3, 4 ) - DateTime( 2025, 1, 1 )
print "  chrono returns a TimeSpan:"
print "    days    = "; gap.TotalDays
print "    hours   = "; gap.TotalHours
print "    minutes = "; gap.TotalMinutes
print "    as text = " & gap.ToIsoString( )

print
print "=== parsing: lenient stays available, strict is new ==="
'' This is not a strawman.  The legacy parser ACCEPTS this and reads the
'' leading "03" as the YEAR 1903 -- silently, with no error to check.
dim as string ambiguous = "03/04/25"
dim as double legacyParsed = DateValue( ambiguous )
print "  legacy IsDate( """ & ambiguous & """ ) = "; IsDate( ambiguous );
print "  and reads it as "; Year( legacyParsed ); Month( legacyParsed ); Day( legacyParsed )
print "  ...which is almost certainly not what the writer meant."

dim as DateTime p
print "  chrono TryParseIso = "; DateTime.TryParseIso( ambiguous, p );
print "   <- refuses: two-digit years have no century rule and never will"
print "  chrono TryParseExact( ""dd/MM/yy"" ) = "; _
      DateTime.TryParseExact( ambiguous, "dd/MM/yy", p );
print "   <- also refuses, for the same reason"
print "  say the century and it works: TryParseExact( ""2025-03-04"", ""yyyy-MM-dd"" ) = "; _
      DateTime.TryParseExact( "2025-03-04", "yyyy-MM-dd", p ); "  -> " & p.ToIsoString( )

print
print "=== timing: TIMER is the wall clock, Stopwatch is not ==="
dim as double t0 = timer
dim as Stopwatch sw = Stopwatch.StartNew( )
sleep 120, 1
sw.Stop_( )
print "  TIMER     measured "; int( ( timer - t0 ) * 1000 ); " ms  (jumps if the clock is adjusted)"
print "  Stopwatch measured "; sw.ElapsedMilliseconds; " ms  (monotonic)"

print
print "=== what has no legacy equivalent at all ==="
print "  ISO 8601   : " & Clock.UtcNow( ).ToIsoString( )
print "  a duration : " & TimeSpan.FromHours( 1.5 ).ToIsoString( )
print "  an Instant : "; Clock.UtcNow( ).UnixSeconds; " unix seconds"
print "  UTC offset : "; TimeZoneInfo.LocalOffset( ); " minutes east"
