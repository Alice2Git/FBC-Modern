'' USTRING overloads -- phase 8.
''
'' The contract is narrow and therefore easy to test: every USTRING entry point
'' must agree EXACTLY with its STRING sibling, and non-ASCII text must survive
'' the boundary in both directions.  The suite is named utext rather than
'' ustring because USTRING is a keyword.

#include once "fbcunit.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.utext )

	'' Every producer must agree with its STRING sibling, for every type.
	TEST( producers_match_string_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 ).WithOffset( 330 )
		dim as DateTime u = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 0 )
		dim as DateTime n = DateTime( 2025, 3, 4 )

		dim as ustring a = d.ToIsoUString( )
		dim as ustring b = d.ToIsoString( )
		CU_ASSERT( a = b )
		CU_ASSERT( len( a ) = len( d.ToIsoString( ) ) )   '' ISO is ASCII, so units = bytes

		dim as ustring ua = u.ToIsoUString( )
		dim as ustring ub = u.ToIsoString( )
		CU_ASSERT( ua = ub )
		dim as ustring na = n.ToIsoUString( )
		dim as ustring nb = n.ToIsoString( )
		CU_ASSERT( na = nb )

		dim as ustring ia = Instant.FromTicks( d.Ticks ).ToIsoUString( )
		dim as ustring ib = Instant.FromTicks( d.Ticks ).ToIsoString( )
		CU_ASSERT( ia = ib )

		dim as ustring da = LocalDate( 2025, 3, 4 ).ToIsoUString( )
		dim as ustring db = LocalDate( 2025, 3, 4 ).ToIsoString( )
		CU_ASSERT( da = db )

		dim as ustring ta = LocalTime( 14, 30, 5, 123 ).ToIsoUString( )
		dim as ustring tb = LocalTime( 14, 30, 5, 123 ).ToIsoString( )
		CU_ASSERT( ta = tb )

		dim as ustring sa = TimeSpan( 1, 2, 3, 4, 500 ).ToIsoUString( )
		dim as ustring sb = TimeSpan( 1, 2, 3, 4, 500 ).ToIsoString( )
		CU_ASSERT( sa = sb )

		'' Invalid produces an empty USTRING, not a stale or garbage one
		dim as ustring inv = DateTime.Invalid.ToIsoUString( )
		CU_ASSERT( len( inv ) = 0 )
	END_TEST

	'' A USTRING pattern must format identically to the same STRING pattern.
	TEST( pattern_overloads_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 120 ).WithOffset( 330 )

		dim as string pats( 0 to 6 ) = { _
			"yyyy-MM-dd HH:mm:ss", "dddd, dd MMMM yyyy", "o", "R", _
			"HH:mm:ss.fff", "'at' HH:mm", "yyyy-MM-ddTHH:mm:ssK" }

		for i as integer = 0 to 6
			dim as ustring up = pats( i )
			dim as ustring got = d.ToString( up )
			dim as ustring want = d.ToString( pats( i ) )
			CU_ASSERT( got = want )

			dim as ustring ur
			dim as string sr
			dim as boolean uok = d.TryFormat( up, ur )
			dim as boolean sok = d.TryFormat( pats( i ), sr )
			CU_ASSERT( uok = sok )
			dim as ustring sru = sr
			CU_ASSERT( ur = sru )
		next

		'' a broken pattern fails the same way through both doors
		dim as ustring bad = "yyyy P"
		dim as ustring br
		CU_ASSERT( d.TryFormat( bad, br ) = false )
		CU_ASSERT( len( d.ToString( bad ) ) = 0 )
	END_TEST

	'' Consumers: a USTRING input must parse identically to the STRING form.
	TEST( parse_overloads_ )
		dim as string srcs( 0 to 5 ) = { _
			"2025-03-04T14:30:05Z", "20250304T143005Z", "2025-063T14:30:05Z", _
			"2025-W10-2", "2025-03-04 14:30:05Z", "2025-03-04T14:30:05+05:30" }

		for i as integer = 0 to 5
			dim as ustring us = srcs( i )
			dim as DateTime a, b
			dim as boolean ua = DateTime.TryParseIso( us, a )
			dim as boolean sb = DateTime.TryParseIso( srcs( i ), b )
			CU_ASSERT( ua = sb )
			CU_ASSERT( a.Ticks = b.Ticks )
			CU_ASSERT( a.OffsetMinutes = b.OffsetMinutes )
			CU_ASSERT( DateTime.ParseIso( us ).Ticks = DateTime.ParseIso( srcs( i ) ).Ticks )

			'' TryParse is the same entry point
			dim as DateTime c
			CU_ASSERT( DateTime.TryParse( us, c ) = ua )
		next

		'' rejection behaves identically, and result is still always written
		dim as ustring badU = "2025-02-30"
		dim as DateTime seeded = DateTime( 2025, 1, 1 )
		CU_ASSERT( DateTime.TryParseIso( badU, seeded ) = false )
		CU_ASSERT( seeded.IsValid = false )

		'' the other four types
		dim as ustring iso = "2025-03-04T14:30:05Z"
		dim as Instant i1, i2
		CU_ASSERT( Instant.TryParseIso( iso, i1 ) )
		CU_ASSERT( Instant.TryParseIso( "2025-03-04T14:30:05Z", i2 ) )
		CU_ASSERT( i1.Ticks = i2.Ticks )

		dim as ustring dOnly = "2025-03-04"
		dim as LocalDate ld1, ld2
		CU_ASSERT( LocalDate.TryParseIso( dOnly, ld1 ) )
		CU_ASSERT( LocalDate.TryParseIso( "2025-03-04", ld2 ) )
		CU_ASSERT( ld1.DayNumber = ld2.DayNumber )

		dim as ustring tOnly = "14:30:05"
		dim as LocalTime lt1, lt2
		CU_ASSERT( LocalTime.TryParseIso( tOnly, lt1 ) )
		CU_ASSERT( LocalTime.TryParseIso( "14:30:05", lt2 ) )
		CU_ASSERT( lt1.Ticks = lt2.Ticks )

		dim as ustring dur = "P1DT2H3M4.5S"
		dim as TimeSpan s1, s2
		CU_ASSERT( TimeSpan.TryParseIso( dur, s1 ) )
		CU_ASSERT( TimeSpan.TryParseIso( "P1DT2H3M4.5S", s2 ) )
		CU_ASSERT( s1.Ticks = s2.Ticks )
	END_TEST

	TEST( parse_exact_overloads_ )
		dim as ustring pat = "yyyy-MM-dd HH:mm:ss"
		dim as ustring src = "2025-03-04 14:30:05"
		dim as DateTime a, b

		CU_ASSERT( DateTime.TryParseExact( src, pat, a ) )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 14:30:05", "yyyy-MM-dd HH:mm:ss", b ) )
		CU_ASSERT( a.Ticks = b.Ticks )
		CU_ASSERT( DateTime.ParseExact( src, pat ).Ticks = a.Ticks )

		'' named months and weekdays through the USTRING door
		dim as ustring npat = "dddd, dd MMMM yyyy"
		dim as ustring nsrc = "Tuesday, 04 March 2025"
		CU_ASSERT( DateTime.TryParseExact( nsrc, npat, a ) )
		CU_ASSERT( a.Day = 4 andalso a.Month = 3 )

		'' and the weekday cross-check still bites
		dim as ustring wrong = "Monday, 04 March 2025"
		CU_ASSERT( DateTime.TryParseExact( wrong, npat, a ) = false )
	END_TEST

	'' The point of the phase: non-ASCII must survive the boundary intact.
	TEST( non_ascii_survives_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		'' a pattern whose LITERAL text is non-ASCII
		dim as ustring pat = "yyyy" + wchr( &h00E9 ) + "MM"     '' e-acute
		dim as ustring got = d.ToString( pat )
		CU_ASSERT( len( got ) = 7 )                 '' 2025 + 1 + 03, in code units
		CU_ASSERT( got[0] = asc( "2" ) )
		CU_ASSERT( got[4] = &h00E9 )                '' the accent came through
		CU_ASSERT( got[5] = asc( "0" ) )

		'' a character outside Latin-1, and one outside the BMP
		dim as ustring euro = "yyyy" + wchr( &h20AC ) + "MM"
		dim as ustring ge = d.ToString( euro )
		CU_ASSERT( len( ge ) = 7 )
		CU_ASSERT( ge[4] = &h20AC )

		'' quoted non-ASCII literal runs
		dim as ustring q = "'" + wchr( &h00E9 ) + wchr( &h20AC ) + "' yyyy"
		dim as ustring gq = d.ToString( q )
		CU_ASSERT( len( gq ) = 7 )                  '' 2 + space + 4
		CU_ASSERT( gq[0] = &h00E9 )
		CU_ASSERT( gq[1] = &h20AC )

		'' the same pattern must round-trip: format then parse it back
		dim as ustring rt = "yyyy" + wchr( &h00E9 ) + "MM" + wchr( &h00E9 ) + "dd"
		dim as ustring txt = d.ToString( rt )
		dim as DateTime back
		CU_ASSERT( DateTime.TryParseExact( txt, rt, back ) )
		CU_ASSERT( back.Year = 2025 andalso back.Month = 3 andalso back.Day = 4 )
	END_TEST

	'' Locale names are the one part of this library that is routinely
	'' non-ASCII, and are the reason phase 8 exists at all.
	TEST( locale_ustring_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		dim as ustring ud = d.ToLocaleDateUString( )
		dim as ustring sd = d.ToLocaleDateString( )
		CU_ASSERT( ud = sd )
		CU_ASSERT( len( ud ) > 0 )

		dim as ustring ut = d.ToLocaleTimeUString( )
		dim as ustring st = d.ToLocaleTimeString( )
		CU_ASSERT( ut = st )

		dim as ustring uf = d.ToLocaleUString( )
		dim as ustring sf = d.ToLocaleString( )
		CU_ASSERT( uf = sf )

		for m as long = 1 to 12
			dim as ustring a = DateTime.MonthUName( m )
			dim as ustring b = DateTime.MonthName( m )
			CU_ASSERT( a = b )
			CU_ASSERT( len( a ) > 0 )
			'' a USTRING length counts CODE UNITS, so it can be shorter than
			'' the UTF-8 byte count -- never longer
			dim as string bytes = DateTime.MonthName( m )
			CU_ASSERT( len( a ) <= len( bytes ) )
		next

		for w as long = 1 to 7
			dim as ustring a = DateTime.WeekdayUName( w )
			dim as ustring b = DateTime.WeekdayName( w )
			CU_ASSERT( a = b )
			CU_ASSERT( len( a ) > 0 )
		next

		'' out-of-range stays empty through the USTRING door too
		dim as ustring z1 = DateTime.MonthUName( 0 )
		dim as ustring z2 = DateTime.WeekdayUName( 8 )
		CU_ASSERT( len( z1 ) = 0 )
		CU_ASSERT( len( z2 ) = 0 )
	END_TEST

	'' A broad sweep so the overloads are exercised over the whole range, not
	'' just on the handful of literals above.
	TEST( sweep_ )
		dim as ulongint seed = 2718281828ull

		for i as integer = 1 to 3000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )

			dim as DateTime d = DateTime.FromTicks( t, 0 )
			if d.IsValid = false then continue for

			dim as ustring u = d.ToIsoUString( )
			dim as ustring s = d.ToIsoString( )
			CU_ASSERT( u = s )

			dim as DateTime back
			CU_ASSERT( DateTime.TryParseIso( u, back ) )
			CU_ASSERT( back.Ticks = d.Ticks )
			CU_ASSERT( back.OffsetMinutes = d.OffsetMinutes )
		next
	END_TEST

END_SUITE
