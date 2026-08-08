'' Zones, locale formatting and interop -- RFC-0007-zones-locale-interop.md s6.
''
'' Zone and locale behaviour depends on the machine, so these assert
'' INVARIANTS and cross-checks, never exact strings.  Where a machine's zone
'' makes a DST assertion inapplicable the test SKIPS and says so, rather than
'' passing silently.

#include once "fbcunit.bi"
#include once "vbcompat.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.zones )

	TEST( offsets_ )
		dim as Instant jan = DateTime( 2025, 1, 15, 12, 0, 0, 0 ).AssumeUtc( )
		dim as Instant jul = DateTime( 2025, 7, 15, 12, 0, 0, 0 ).AssumeUtc( )

		dim as short oJan = TimeZoneInfo.LocalOffsetAt( jan )
		dim as short oJul = TimeZoneInfo.LocalOffsetAt( jul )
		dim as short oNow = TimeZoneInfo.LocalOffset( )

		'' every offset is in range and a whole number of minutes
		CU_ASSERT( oJan >= DT_OFFSET_MIN andalso oJan <= DT_OFFSET_MAX )
		CU_ASSERT( oJul >= DT_OFFSET_MIN andalso oJul <= DT_OFFSET_MAX )
		CU_ASSERT( oNow >= DT_OFFSET_MIN andalso oNow <= DT_OFFSET_MAX )

		'' The machine tells us which case applies rather than us assuming a
		'' zone: on a DST-observing machine January and July MUST differ.
		if TimeZoneInfo.SupportsDaylightSavingTime( ) then
			CU_ASSERT( oJan <> oJul )
			'' exactly one of the two is DST
			CU_ASSERT( TimeZoneInfo.IsDaylightSavingTime( jan ) <> _
			           TimeZoneInfo.IsDaylightSavingTime( jul ) )
		else
			CU_ASSERT( oJan = oJul )
			print "  [skip] machine's zone does not observe DST; " & _
			      "the January-vs-July assertions do not apply"
		end if

		'' an Invalid instant does not crash and yields a neutral answer
		CU_ASSERT( TimeZoneInfo.LocalOffsetAt( Instant.Invalid ) = 0 )
		CU_ASSERT( TimeZoneInfo.IsDaylightSavingTime( Instant.Invalid ) = false )
	END_TEST

	'' RFC-0007 section 1 requires the DYNAMIC zone API, so that a date from
	'' before a DST rule change gets that era's rule rather than today's.
	''
	'' North America moved the DST start from early April to mid-March in 2007
	'' (Energy Policy Act 2005), so 20 March is standard time in 2005 and
	'' daylight time in 2025.  A static-rules implementation reports today's
	'' rule for both and the two offsets come out equal.
	''
	'' This only discriminates on a zone that actually had a rule change in
	'' that window, so it SKIPS and says so elsewhere rather than passing
	'' vacuously.
	TEST( historical_rules_ )
		if TimeZoneInfo.SupportsDaylightSavingTime( ) = false then
			print "  [skip] zone does not observe DST; historical rules not testable here"
		else
			dim as Instant old2005 = DateTime( 2005, 3, 20, 12, 0, 0, 0 ).AssumeUtc( )
			dim as Instant new2025 = DateTime( 2025, 3, 20, 12, 0, 0, 0 ).AssumeUtc( )
			dim as short o05 = TimeZoneInfo.LocalOffsetAt( old2005 )
			dim as short o25 = TimeZoneInfo.LocalOffsetAt( new2025 )

			dim as Instant jan = DateTime( 2025, 1, 15, 12, 0, 0, 0 ).AssumeUtc( )
			dim as short std = TimeZoneInfo.LocalOffsetAt( jan )

			if o05 <> o25 then
				'' the 2007 rule change is visible: 2005 is still standard time
				CU_ASSERT( o05 = std )
				CU_ASSERT( o25 <> std )
			else
				'' WARNING, not a clean skip.  Equal offsets mean EITHER this
				'' zone had no 2007-era rule change, OR the implementation
				'' regressed to the static zone API and is applying today's
				'' rule to 2005.  The two are indistinguishable from here, so
				'' this branch cannot assert -- see RFC-0007 s6, which records
				'' that the dynamic-API requirement is verified by manual
				'' inspection rather than by a portable automated test.
				print "  [warn] 2005 and 2025 March offsets are equal (" & o05 & _
				      "); either this zone had no 2007 rule change, or the " & _
				      "dynamic zone API is not being used"
			end if
		end if
	END_TEST

	'' The round trip that catches an offset sign error at an ARBITRARY
	'' instant, not just now.
	TEST( local_roundtrip_ )
		dim as ulongint seed = 5772156649ull

		for i as integer = 1 to 2000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			'' keep inside the range time_t can express on every platform
			dim as longint t = DT_TICKS_TO_UNIX_EPOCH + _
			                   clngint( ( seed shr 20 ) mod 60000000000000000ull )
			if fb_DtIsValidTicks( t ) = 0 then continue for

			dim as Instant src = Instant.FromTicks( t )
			dim as short off = TimeZoneInfo.LocalOffsetAt( src )
			dim as DateTime loc = DateTime.FromInstant( src, off )
			CU_ASSERT( loc.IsValid )
			'' converting back must land on the same instant, DST or not,
			'' because the value records the offset it was built with
			CU_ASSERT( loc.ToInstant( ).Ticks = src.Ticks )
		next
	END_TEST

	'' RFC-0007 section 2: exact vs calendar-preserving arithmetic.  They
	'' differ exactly twice a year, and that is the point.
	TEST( calendar_vs_exact_days_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 12, 0, 0, 0 ) _
		                    .WithOffset( TimeZoneInfo.LocalOffset( ) )

		'' away from any boundary the two agree
		CU_ASSERT( d.AddDays( 1 ).Hour = d.AddCalendarDays( 1 ).Hour )

		'' AddDays is exactly 86400 seconds, always
		CU_ASSERT( d.AddDays( 1 ).Ticks - d.Ticks = DT_TICKS_PER_DAY )

		'' AddCalendarDays keeps the wall-clock reading, always
		for k as integer = 1 to 365
			dim as DateTime a = DateTime( 2025, 1, 1, 12, 0, 0, 0 ) _
			                    .WithOffset( TimeZoneInfo.LocalOffset( ) ) _
			                    .AddCalendarDays( k )
			CU_ASSERT( a.IsValid )
			CU_ASSERT( a.Hour = 12 )
			CU_ASSERT( a.Minute = 0 )
		next

		'' Find a real DST transition by scanning the year, then assert the two
		'' operations actually disagree across it.  Nothing is assumed about
		'' which zone this machine is in.
		if TimeZoneInfo.SupportsDaylightSavingTime( ) then
			dim as boolean found = false
			dim as Instant prev = DateTime( 2025, 1, 1, 12, 0, 0, 0 ).AssumeUtc( )
			dim as short prevOff = TimeZoneInfo.LocalOffsetAt( prev )

			for k as integer = 1 to 364
				dim as Instant cur = prev.Add( TimeSpan.FromDays( 1 ) )
				dim as short curOff = TimeZoneInfo.LocalOffsetAt( cur )
				if curOff <> prevOff then
					'' local noon on the day before the shift
					dim as DateTime before = DateTime.FromInstant( prev, prevOff ).StartOfDay( ) _
					                         .AddHours( 12 ).WithOffset( prevOff )
					dim as DateTime exact = before.AddDays( 1 )
					dim as DateTime civil = before.AddCalendarDays( 1 )
					CU_ASSERT( exact.IsValid andalso civil.IsValid )

					'' The civil one keeps the wall reading AND re-resolves the
					'' offset.  Asserting only the hour is NOT enough: with a
					'' fixed offset, plain AddDays keeps the hour too, so that
					'' assertion alone cannot tell the two apart.  The offset is
					'' what actually distinguishes them.
					CU_ASSERT( civil.Hour = 12 )
					CU_ASSERT( civil.OffsetMinutes = curOff )
					CU_ASSERT( civil.OffsetMinutes <> before.OffsetMinutes )

					'' exact arithmetic is 24 h of real time; the civil one is
					'' 23 or 25 h across the shift
					CU_ASSERT( exact.ToInstant( ).Ticks - before.ToInstant( ).Ticks = DT_TICKS_PER_DAY )
					CU_ASSERT( civil.ToInstant( ).Ticks - before.ToInstant( ).Ticks <> DT_TICKS_PER_DAY )
					CU_ASSERT( civil.ToInstant( ).Ticks <> exact.ToInstant( ).Ticks )
					found = true
					exit for
				end if
				prev = cur
				prevOff = curOff
			next
			if found = false then
				print "  [skip] no DST transition found in 2025 for this machine's zone"
			end if
		else
			print "  [skip] machine's zone does not observe DST"
		end if
	END_TEST

	'' Hardcoded anchors, one per representation.  These catch an epoch
	'' constant off by a century, which no relative test ever does.
	TEST( interop_anchors_ )
		CU_ASSERT( Instant.FromUnixSeconds( 0 ).ToIsoString( ) = "1970-01-01T00:00:00Z" )
		CU_ASSERT( Instant.FromUnixSeconds( 1000000000 ).ToIsoString( ) = "2001-09-09T01:46:40Z" )
		CU_ASSERT( Instant.FromUnixMilliseconds( 0 ).ToIsoString( ) = "1970-01-01T00:00:00Z" )
		CU_ASSERT( Instant.FromUnixMicroseconds( 0 ).ToIsoString( ) = "1970-01-01T00:00:00Z" )

		CU_ASSERT( DateTime.FromFileTime( 0 ).ToIsoString( ) = "1601-01-01T00:00:00Z" )
		CU_ASSERT( DateTime.FromOleDate( 0.0 ).Year = 1899 )
		CU_ASSERT( DateTime.FromOleDate( 0.0 ).Month = 12 )
		CU_ASSERT( DateTime.FromOleDate( 0.0 ).Day = 30 )
		CU_ASSERT( DateTime.FromOleDate( 1.0 ).Day = 31 )

		'' the constants themselves
		CU_ASSERT( DT_TICKS_TO_UNIX_EPOCH = 621355968000000000ll )
		CU_ASSERT( DT_TICKS_TO_FILETIME = 504911232000000000ll )
		CU_ASSERT( DT_TICKS_TO_OLE_EPOCH = 599264352000000000ll )
	END_TEST

	TEST( interop_roundtrip_ )
		dim as ulongint seed = 1618033988ull

		for i as integer = 1 to 3000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )
			dim as Instant a = Instant.FromTicks( t )
			if a.IsValid = false then continue for

			'' each converter round-trips at its own precision
			CU_ASSERT( Instant.FromUnixSeconds( a.UnixSeconds ).Ticks = _
			           a.Ticks - ( ( a.Ticks - DT_TICKS_TO_UNIX_EPOCH ) mod DT_TICKS_PER_SECOND + _
			                       DT_TICKS_PER_SECOND ) mod DT_TICKS_PER_SECOND )

			'' FILETIME's epoch is 1601-01-01, so it simply cannot represent an
			'' earlier instant.  Round-trip above that; assert Invalid below it
			'' rather than skipping, so the boundary is actually tested.
			dim as DateTime d = DateTime.FromTicks( t, 0 )
			if t >= DT_TICKS_TO_FILETIME then
				CU_ASSERT( d.FileTime >= 0 )
				CU_ASSERT( DateTime.FromFileTime( d.FileTime ).Ticks = d.Ticks )
			else
				CU_ASSERT( d.FileTime < 0 )
				CU_ASSERT( DateTime.FromFileTime( d.FileTime ).IsValid = false )
			end if
		next

		'' the FILETIME epoch boundary itself
		CU_ASSERT( DateTime.FromTicks( DT_TICKS_TO_FILETIME, 0 ).FileTime = 0 )
		CU_ASSERT( DateTime.FromTicks( DT_TICKS_TO_FILETIME - 1, 0 ).FileTime = -1 )
		CU_ASSERT( DateTime.FromFileTime( 0 ).IsValid )

		'' pre-1970 must floor toward minus infinity, not toward zero
		CU_ASSERT( Instant.FromUnixSeconds( -1 ).UnixSeconds = -1 )
		CU_ASSERT( Instant.FromTicks( Instant.FromUnixSeconds( 0 ).Ticks - 1 ).UnixSeconds = -1 )
		CU_ASSERT( Instant.FromTicks( Instant.FromUnixSeconds( 0 ).Ticks - _
		                              DT_TICKS_PER_SECOND ).UnixSeconds = -1 )

		'' overflow
		CU_ASSERT( Instant.FromUnixSeconds( 9223372036854775807ll ).IsValid = false )
		CU_ASSERT( Instant.FromUnixSeconds( -9223372036854775807ll ).IsValid = false )
		CU_ASSERT( DateTime.FromFileTime( -1 ).IsValid = false )
	END_TEST

	'' The assertion that the migration path actually works: chrono and
	'' datetime.bi must agree on the same serial double.
	TEST( legacy_serial_bridge_ )
		for y as long = 1900 to 2100 step 7
			for m as long = 1 to 12 step 3
				dim as double leg = DateSerial( y, m, 15 )
				dim as DateTime mine = DateTime.FromSerial( leg )
				CU_ASSERT( mine.IsValid )
				CU_ASSERT( mine.Year = y )
				CU_ASSERT( mine.Month = m )
				CU_ASSERT( mine.Day = 15 )

				'' and back the other way, read by the legacy accessors
				dim as double back = DateTime( y, m, 15 ).Serial
				CU_ASSERT( Year( back ) = y )
				CU_ASSERT( Month( back ) = m )
				CU_ASSERT( Day( back ) = 15 )
			next
		next

		'' serial is lossy below about a millisecond, so the round trip is
		'' asserted at millisecond precision and the limit is stated, not hidden
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )
		dim as DateTime r = DateTime.FromSerial( d.Serial )
		CU_ASSERT( r.IsValid )
		CU_ASSERT( abs( r.Ticks - d.Ticks ) < DT_TICKS_PER_MILLISECOND )
	END_TEST

	'' Locale output is whatever the machine says.  INVARIANTS ONLY -- no exact
	'' string assertions are possible here, and pretending otherwise would be
	'' either locale-pinning or lying.
	TEST( locale_invariants_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		dim as string sd = d.ToLocaleDateString( lsShort )
		dim as string ld = d.ToLocaleDateString( lsLong )
		dim as string st = d.ToLocaleTimeString( lsShort )
		dim as string full = d.ToLocaleString( lsShort )

		CU_ASSERT( len( sd ) > 0 )
		CU_ASSERT( len( ld ) > 0 )
		CU_ASSERT( len( st ) > 0 )
		CU_ASSERT( len( full ) >= len( sd ) )
		CU_ASSERT( len( ld ) >= len( sd ) )      '' long is at least as long
		CU_ASSERT( len( sd ) < 100 )
		CU_ASSERT( len( ld ) < 200 )

		'' all twelve month names present and distinct
		'' NOTE the temporaries: CU_ASSERT is a macro, so a comma inside a call
		'' in its argument would split the macro's arguments.
		dim as string mn( 1 to 12 )
		for m as long = 1 to 12
			mn( m ) = DateTime.MonthName( m )
			dim as string ab = DateTime.MonthName( m, true )
			dim as long lf = len( mn( m ) )
			dim as long la = len( ab )
			CU_ASSERT( lf > 0 )
			CU_ASSERT( la > 0 )
			'' abbreviated is never longer than full
			CU_ASSERT( la <= lf )
		next
		for a as long = 1 to 12
			for b as long = a + 1 to 12
				CU_ASSERT( mn( a ) <> mn( b ) )
			next
		next

		'' all seven weekday names present and distinct
		dim as string wn( 1 to 7 )
		for w as long = 1 to 7
			wn( w ) = DateTime.WeekdayName( w )
			dim as string wab = DateTime.WeekdayName( w, true )
			dim as long lwf = len( wn( w ) )
			dim as long lwa = len( wab )
			CU_ASSERT( lwf > 0 )
			CU_ASSERT( lwa <= lwf )
		next
		for a as long = 1 to 7
			for b as long = a + 1 to 7
				CU_ASSERT( wn( a ) <> wn( b ) )
			next
		next

		'' out-of-range indices give empty, not garbage
		CU_ASSERT( DateTime.MonthName( 0 ) = "" )
		CU_ASSERT( DateTime.MonthName( 13 ) = "" )
		CU_ASSERT( DateTime.WeekdayName( 0 ) = "" )
		CU_ASSERT( DateTime.WeekdayName( 8 ) = "" )
		CU_ASSERT( DateTime.Invalid.ToLocaleDateString( ) = "" )

		'' zone names are non-empty and, where DST exists, distinct
		dim as string zStd = TimeZoneInfo.StandardName( )
		dim as string zDst = TimeZoneInfo.DaylightName( )
		CU_ASSERT( len( zStd ) > 0 )
		if TimeZoneInfo.SupportsDaylightSavingTime( ) then
			CU_ASSERT( len( zDst ) > 0 )
			CU_ASSERT( zStd <> zDst )
		end if
	END_TEST

END_SUITE
