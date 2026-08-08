'' Standalone Linux verification for fb/chrono.bi.
''
'' The fbcunit suites cannot be linked on a machine without libxpm-dev, because
'' the suite pulls in gfxlib2.  This program needs no gfx, so it can run the
'' platform-specific code -- unix/dt_clock.c and unix/dt_zone.c -- which is the
'' part the Windows gates could never reach.
''
'' Build and run (in WSL, from FBC-Modern/src):
''   bin/fbc -i inc ../tests/chrono_linux_check.bas -x /tmp/chk && /tmp/chk

#include once "vbcompat.bi"
#include once "fb/chrono.bi"

using FB

dim shared as long g_run, g_fail

sub chk( byval cond as boolean, byref what as string )
	g_run += 1
	if cond = false then
		g_fail += 1
		print "FAIL: " & what
	end if
end sub

print "chrono -- Linux verification"
print

'' ---------------------------------------------------------------- kernel
dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )
chk( d.IsValid, "construct" )
chk( d.Year = 2025 andalso d.Month = 3 andalso d.Day = 4, "date components" )
chk( d.Hour = 14 andalso d.Minute = 30 andalso d.Second = 5, "time components" )
chk( d.DayOfWeek = DT_TUESDAY, "day of week is ISO" )
chk( d.DayOfYear = 63, "day of year" )
chk( d.IsoWeek = 10, "iso week" )
chk( DateTime( 2025, 2, 30 ).IsValid = false, "invalid date rejected" )
chk( DateTime( 2024, 2, 29 ).IsValid, "leap day accepted" )
chk( DateTime.MaxValue.AddTicks( 1 ).IsValid = false, "overflow does not wrap" )
chk( DateTime( 2025, 1, 31 ).AddMonths( 1 ).Day = 28, "end-of-month clamp" )
chk( DateTime( 2025, 12, 29 ).IsoWeekYear = 2026, "iso week-year" )

'' ------------------------------------------------------------------- ISO
chk( d.ToIsoString( ) = "2025-03-04T14:30:05.1230000", "iso emit naive" )
chk( d.WithOffset( 0 ).ToIsoString( ) = "2025-03-04T14:30:05.1230000Z", "iso emit utc" )
chk( d.WithOffset( 330 ).ToIsoString( ) = "2025-03-04T14:30:05.1230000+05:30", "iso emit offset" )
dim as DateTime p
chk( DateTime.TryParseIso( "2025-063T14:30:05Z", p ), "iso ordinal parse" )
chk( p.Month = 3 andalso p.Day = 4, "iso ordinal value" )
chk( DateTime.TryParseIso( "2025-W10-2", p ), "iso week-date parse" )
chk( p.Day = 4, "iso week-date value" )
chk( DateTime.TryParseIso( "2025-03-04T24:00:00Z", p ) = false, "24:00 rejected" )
chk( DateTime.TryParseIso( "03/04/25", p ) = false, "two-digit year rejected" )

'' --------------------------------------------------------------- pattern
chk( d.ToString( "yyyy-MM-dd HH:mm:ss" ) = "2025-03-04 14:30:05", "pattern basic" )
chk( d.ToString( "dddd, dd MMMM yyyy" ) = "Tuesday, 04 March 2025", "pattern names invariant" )
chk( d.WithOffset( 330 ).ToString( "R" ) = "Tue, 04 Mar 2025 09:00:05 GMT", "RFC 1123 converts to UTC" )
chk( d.ToString( "o" ) = d.ToIsoString( ), "o matches ToIsoString" )
chk( DateTime( 2025, 3, 4, 0, 0, 0, 0 ).ToString( "h tt" ) = "12 AM", "12-hour midnight" )

'' ---------------------------------------------------- clocks (PER-OS CODE)
dim as Instant u1 = Clock.UtcNow( )
dim as Instant u2 = Clock.UtcNow( )
chk( u1.IsValid andalso u2.IsValid, "UtcNow valid" )
chk( u2.Ticks >= u1.Ticks, "UtcNow non-decreasing" )
chk( u1.Ticks > 638700000000000000ll, "UtcNow past build era (epoch constant)" )
chk( Clock.Resolution( ).Ticks > 0, "clock resolution positive" )

dim as DateTime nowLocal = Clock.Now( )
chk( nowLocal.IsValid andalso nowLocal.HasOffset, "Now carries an offset" )
'' cross-check the LOCAL WALL READING against datetime.bi, which reaches the OS
'' by a completely separate path -- this is what catches an offset sign error
dim as double legacyNow = Now( )
dim as double mine = ( nowLocal.Ticks - DT_TICKS_TO_OLE_EPOCH ) / DT_TICKS_PER_DAY
chk( abs( legacyNow - mine ) * 86400.0 < 2.0, "local wall reading matches datetime.bi" )
chk( nowLocal.Year = Year( legacyNow ), "local year matches legacy" )
chk( nowLocal.Hour = Hour( legacyNow ), "local hour matches legacy" )

dim as Stopwatch sw = Stopwatch.StartNew( )
sleep 120, 1
sw.Stop_( )
chk( sw.ElapsedMilliseconds >= 100, "stopwatch measured a sleep" )
chk( sw.ElapsedMilliseconds < 2000, "stopwatch not wildly wrong" )
chk( Stopwatch.Frequency > 0, "stopwatch frequency" )
chk( Stopwatch.IsHighResolution, "monotonic clock available" )
'' the pure scaling function, the one place a silent wrong answer is easy
chk( fb_DtTicksFromCounts( 24ll*3600ll*10000000ll, 10000000ll ) = 24ll*DT_TICKS_PER_HOUR, _
     "count scaling: 24h at 10MHz" )
chk( fb_DtTicksFromCounts( 7ll*24ll*3600ll*10000000ll, 10000000ll ) = 7ll*24ll*DT_TICKS_PER_HOUR, _
     "count scaling: one week at 10MHz (128-bit path)" )

dim as TimeSpan c0 = CpuClock.ProcessTime( )
chk( c0.IsValid, "cpu time valid" )
dim as double acc = 0
dim as Stopwatch guard = Stopwatch.StartNew( )
dim as TimeSpan c1 = c0
do
	for i as integer = 1 to 2000000
		acc += i * 0.5
	next
	c1 = CpuClock.ProcessTime( )
loop until c1.Ticks > c0.Ticks orelse guard.Elapsed.TotalSeconds > 5.0
chk( acc > 0, "work not optimised away" )
chk( c1.Ticks > c0.Ticks, "cpu time advances with work" )
'' a sleep must NOT advance the CPU clock the way it advances the wall clock
dim as TimeSpan c2 = CpuClock.ProcessTime( )
dim as Instant w2 = Clock.UtcNow( )
sleep 200, 1
dim as TimeSpan c3 = CpuClock.ProcessTime( )
dim as Instant w3 = Clock.UtcNow( )
chk( ( w3 - w2 ).TotalMilliseconds > 150, "wall clock advanced over sleep" )
chk( ( c3 - c2 ).TotalMilliseconds < ( w3 - w2 ).TotalMilliseconds / 2, _
     "cpu clock did NOT advance over sleep" )

'' ----------------------------------------------------- zones (PER-OS CODE)
dim as Instant jan = DateTime( 2025, 1, 15, 12, 0, 0, 0 ).AssumeUtc( )
dim as Instant jul = DateTime( 2025, 7, 15, 12, 0, 0, 0 ).AssumeUtc( )
dim as short oJan = TimeZoneInfo.LocalOffsetAt( jan )
dim as short oJul = TimeZoneInfo.LocalOffsetAt( jul )
chk( oJan >= DT_OFFSET_MIN andalso oJan <= DT_OFFSET_MAX, "jan offset in range" )
chk( oJul >= DT_OFFSET_MIN andalso oJul <= DT_OFFSET_MAX, "jul offset in range" )
print "  [info] zone = '" & TimeZoneInfo.StandardName( ) & "' / '" & _
      TimeZoneInfo.DaylightName( ) & "'  jan=" & oJan & " jul=" & oJul & _
      " dst=" & TimeZoneInfo.SupportsDaylightSavingTime( )
if TimeZoneInfo.SupportsDaylightSavingTime( ) then
	chk( oJan <> oJul, "DST zone: jan and jul offsets differ" )
	chk( TimeZoneInfo.IsDaylightSavingTime( jan ) <> TimeZoneInfo.IsDaylightSavingTime( jul ), _
	     "exactly one of jan/jul is DST" )
else
	chk( oJan = oJul, "non-DST zone: offsets equal" )
	print "  [skip] zone does not observe DST"
end if
dim as string zname = TimeZoneInfo.StandardName( )
chk( len( zname ) > 0, "standard zone name non-empty" )

'' the round trip that must hold across DST, at arbitrary instants
dim as ulongint seed = 5772156649ull
for i as integer = 1 to 2000
	seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
	dim as longint t = DT_TICKS_TO_UNIX_EPOCH + clngint( ( seed shr 20 ) mod 60000000000000000ull )
	if fb_DtIsValidTicks( t ) = 0 then continue for
	dim as Instant src = Instant.FromTicks( t )
	dim as DateTime lt = DateTime.FromInstant( src, TimeZoneInfo.LocalOffsetAt( src ) )
	if lt.IsValid = false orelse lt.ToInstant( ).Ticks <> src.Ticks then
		chk( false, "local round trip at tick " & t )
		exit for
	end if
next
g_run += 1   '' the loop above counts as one assertion when it passes

'' ---------------------------------------------------- locale (PER-OS CODE)
print "  [info] locale date='" & d.ToLocaleDateString( ) & "' time='" & _
      d.ToLocaleTimeString( ) & "' month3='" & DateTime.MonthName( 3 ) & _
      "' weekday2='" & DateTime.WeekdayName( 2 ) & "'"
chk( len( d.ToLocaleDateString( ) ) > 0, "locale date non-empty" )
chk( len( d.ToLocaleTimeString( ) ) > 0, "locale time non-empty" )
dim as string mn( 1 to 12 )
for m as long = 1 to 12
	mn( m ) = DateTime.MonthName( m )
	chk( len( mn( m ) ) > 0, "month name " & m & " non-empty" )
next
dim as boolean allDistinct = true
for a as long = 1 to 12
	for b as long = a + 1 to 12
		if mn( a ) = mn( b ) then allDistinct = false
	next
next
chk( allDistinct, "all twelve month names distinct" )
dim as string wn( 1 to 7 )
dim as boolean wDistinct = true
for w as long = 1 to 7
	wn( w ) = DateTime.WeekdayName( w )
	chk( len( wn( w ) ) > 0, "weekday name " & w & " non-empty" )
next
for a as long = 1 to 7
	for b as long = a + 1 to 7
		if wn( a ) = wn( b ) then wDistinct = false
	next
next
chk( wDistinct, "all seven weekday names distinct" )
chk( DateTime.MonthName( 0 ) = "", "month 0 empty" )
chk( DateTime.WeekdayName( 8 ) = "", "weekday 8 empty" )

'' --------------------------------------------------------------- interop
chk( Instant.FromUnixSeconds( 0 ).ToIsoString( ) = "1970-01-01T00:00:00Z", "unix epoch" )
chk( Instant.FromUnixSeconds( 1000000000 ).ToIsoString( ) = "2001-09-09T01:46:40Z", "unix 1e9" )
chk( DateTime.FromFileTime( 0 ).ToIsoString( ) = "1601-01-01T00:00:00Z", "filetime epoch" )
chk( DateTime.FromOleDate( 0.0 ).Year = 1899, "ole epoch" )
chk( Instant.FromUnixSeconds( -1 ).UnixSeconds = -1, "negative unix floors" )
'' the legacy bridge, cross-checked against datetime.bi itself
for y as long = 1950 to 2050 step 13
	dim as double leg = DateSerial( y, 6, 15 )
	dim as DateTime m2 = DateTime.FromSerial( leg )
	chk( m2.Year = y andalso m2.Month = 6 andalso m2.Day = 15, "serial bridge " & y )
next

'' --------------------------------------------------------------- ustring
dim as ustring uiso = d.ToIsoUString( )
dim as ustring siso = d.ToIsoString( )
chk( uiso = siso, "ustring iso matches string" )
dim as ustring upat = "yyyy-MM-dd"
chk( d.ToString( upat ) = d.ToString( "yyyy-MM-dd" ), "ustring pattern matches" )
dim as ustring usrc = "2025-03-04T14:30:05Z"
dim as DateTime up
chk( DateTime.TryParseIso( usrc, up ), "ustring parse" )
chk( up.Ticks = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks, "ustring parse value" )

'' ----------------------------------------------------------- broad sweep
dim as ulongint s2 = 3141592653ull
for i as integer = 1 to 20000
	s2 = ( s2 * 6364136223846793005ull + 1442695040888963407ull )
	dim as longint t = clngint( s2 mod culngint( DT_MAX_TICKS ) )
	dim as DateTime a = DateTime.FromTicks( t, 0 )
	if a.IsValid = false then continue for
	dim as DateTime b = DateTime.ParseIso( a.ToIsoString( ) )
	if b.IsValid = false orelse b.Ticks <> a.Ticks then
		chk( false, "iso round trip at tick " & t )
		exit for
	end if
	dim as DateTime c = DateTime.FromDateTime( a.GetDate( ), a.GetTimeOfDay( ) )
	if c.Ticks <> t then
		chk( false, "decompose/recompose at tick " & t )
		exit for
	end if
next
g_run += 2

print
print using "###### checks, ###### failures"; g_run; g_fail
if g_fail > 0 then end 1
