'' Custom patterns -- C:\dev\docs\datetime\RFC-0006-patterns.md section 6.
''
'' Every assertion here is an EXACT string, which is possible only because this
'' layer uses invariant English and never consults the locale.

#include once "fbcunit.bi"
#include once "crt/locale.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.pattern )

	TEST( format_date_fields_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		CU_ASSERT( d.ToString( "y" ) = "2025" )
		CU_ASSERT( d.ToString( "yy" ) = "25" )
		CU_ASSERT( d.ToString( "yyyy" ) = "2025" )
		CU_ASSERT( d.ToString( "yyyyy" ) = "02025" )
		CU_ASSERT( DateTime( 1, 1, 1 ).ToString( "yyyy" ) = "0001" )

		CU_ASSERT( d.ToString( "M" ) = "3" )
		CU_ASSERT( d.ToString( "MM" ) = "03" )
		CU_ASSERT( d.ToString( "MMM" ) = "Mar" )
		CU_ASSERT( d.ToString( "MMMM" ) = "March" )
		CU_ASSERT( DateTime( 2025, 12, 1 ).ToString( "MMMM" ) = "December" )

		CU_ASSERT( d.ToString( "d," ) = "4," )
		CU_ASSERT( d.ToString( "dd" ) = "04" )
		CU_ASSERT( d.ToString( "ddd" ) = "Tue" )
		CU_ASSERT( d.ToString( "dddd" ) = "Tuesday" )

		CU_ASSERT( d.ToString( "D," ) = "63," )
		CU_ASSERT( d.ToString( "DDD" ) = "063" )
		CU_ASSERT( d.ToString( "Q" ) = "1" )
		CU_ASSERT( DateTime( 2025, 12, 1 ).ToString( "Q" ) = "4" )
		CU_ASSERT( d.ToString( "ww" ) = "10" )
		CU_ASSERT( DateTime( 2025, 12, 29 ).ToString( "ww" ) = "01" )
		CU_ASSERT( DateTime( 2025, 12, 29 ).ToString( "Y" ) = "2026" )   '' ISO week-year
		CU_ASSERT( DateTime( 2025, 12, 29 ).ToString( "yyyy" ) = "2025" )
		CU_ASSERT( d.ToString( "g" ) = "A.D." )
	END_TEST

	TEST( format_time_fields_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		CU_ASSERT( d.ToString( "H," ) = "14," )
		CU_ASSERT( d.ToString( "HH" ) = "14" )
		CU_ASSERT( d.ToString( "h," ) = "2," )
		CU_ASSERT( d.ToString( "hh" ) = "02" )
		CU_ASSERT( d.ToString( "m," ) = "30," )
		CU_ASSERT( d.ToString( "mm" ) = "30" )
		CU_ASSERT( d.ToString( "s," ) = "5," )
		CU_ASSERT( d.ToString( "ss" ) = "05" )
		CU_ASSERT( d.ToString( "t," ) = "P," )
		CU_ASSERT( d.ToString( "tt" ) = "PM" )

		'' the 12-hour edge cases: 00:00 is 12 AM, 12:00 is 12 PM
		CU_ASSERT( DateTime( 2025, 3, 4, 0, 0, 0, 0 ).ToString( "h tt" ) = "12 AM" )
		CU_ASSERT( DateTime( 2025, 3, 4, 12, 0, 0, 0 ).ToString( "h tt" ) = "12 PM" )
		CU_ASSERT( DateTime( 2025, 3, 4, 11, 59, 0, 0 ).ToString( "h tt" ) = "11 AM" )
		CU_ASSERT( DateTime( 2025, 3, 4, 13, 0, 0, 0 ).ToString( "h tt" ) = "1 PM" )
		CU_ASSERT( DateTime( 2025, 3, 4, 23, 0, 0, 0 ).ToString( "hh tt" ) = "11 PM" )

		CU_ASSERT( DateTime( 2025, 1, 2, 3, 4, 5, 0 ).ToString( "yyyy-MM-dd HH:mm:ss" ) = _
		           "2025-01-02 03:04:05" )
	END_TEST

	'' The f/F distinction, which is the reason both exist.
	TEST( format_fractions_ )
		dim as DateTime a = DateTime( 2025, 3, 4, 0, 0, 0, 120 )    '' .1200000
		dim as DateTime z = DateTime( 2025, 3, 4, 0, 0, 0, 0 )      '' .0000000

		CU_ASSERT( a.ToString( "fff" ) = "120" )
		CU_ASSERT( a.ToString( "FFF" ) = "12" )
		CU_ASSERT( a.ToString( "f," ) = "1," )
		CU_ASSERT( a.ToString( "fffffff" ) = "1200000" )
		CU_ASSERT( a.ToString( "FFFFFFF" ) = "12" )

		CU_ASSERT( z.ToString( "fff" ) = "000" )
		CU_ASSERT( z.ToString( "FFF" ) = "" )

		'' an F field that vanishes takes an adjacent literal '.' with it
		CU_ASSERT( z.ToString( "HH:mm:ss.FFF" ) = "00:00:00" )
		CU_ASSERT( a.ToString( "HH:mm:ss.FFF" ) = "00:00:00.12" )
		CU_ASSERT( z.ToString( "HH:mm:ss.fff" ) = "00:00:00.000" )
	END_TEST

	TEST( format_offsets_ )
		dim as DateTime o = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 330 )
		dim as DateTime u = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 0 )
		dim as DateTime n = DateTime( 2025, 3, 4, 14, 30, 5, 0 )
		dim as DateTime w = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( -300 )

		CU_ASSERT( o.ToString( "zzz" ) = "+05:30" )
		CU_ASSERT( o.ToString( "zz" ) = "+05" )
		CU_ASSERT( o.ToString( "z," ) = "+5," )
		CU_ASSERT( w.ToString( "zzz" ) = "-05:00" )

		CU_ASSERT( u.ToString( "K" ) = "Z" )
		CU_ASSERT( o.ToString( "K" ) = "+05:30" )
		CU_ASSERT( n.ToString( "K" ) = "" )       '' unspecified emits nothing
		'' ...and a valid pattern producing an empty string is still a SUCCESS
		dim as string r
		CU_ASSERT( n.TryFormat( "K", r ) )
		CU_ASSERT( r = "" )
	END_TEST

	TEST( literals_and_escaping_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )
		dim as string r

		CU_ASSERT( d.ToString( "'at' HH:mm" ) = "at 14:30" )
		CU_ASSERT( d.ToString( "\H\Hmm" ) = "HH30" )
		CU_ASSERT( d.ToString( "yyyy-MM-dd" ) = "2025-03-04" )
		CU_ASSERT( d.ToString( "HH:mm:ss" ) = "14:30:05" )
		'' '' is an apostrophe INSIDE a quoted run (RFC-0006 s3); on its own it
		'' is simply an empty literal run and emits nothing.
		CU_ASSERT( d.ToString( "'it''s' HH" ) = "it's 14" )
		CU_ASSERT( d.ToString( "''" ) = "" )
		CU_ASSERT( d.ToString( "\'HH" ) = "'14" )
		CU_ASSERT( d.ToString( "[HH]" ) = "[14]" )

		'' pattern errors -> TryFormat false, ToString empty
		CU_ASSERT( d.TryFormat( "'abc", r ) = false )       '' unterminated quote
		CU_ASSERT( d.ToString( "'abc" ) = "" )
		CU_ASSERT( d.TryFormat( "yyyy P", r ) = false )     '' unknown letter
		CU_ASSERT( d.TryFormat( "yyyy x", r ) = false )
		CU_ASSERT( d.TryFormat( "\", r ) = false )          '' dangling escape
		CU_ASSERT( d.TryFormat( "MMMMM", r ) = false )      '' run too long
		CU_ASSERT( d.TryFormat( "HHH", r ) = false )

		'' an Invalid receiver
		CU_ASSERT( DateTime.Invalid.TryFormat( "yyyy", r ) = false )
		CU_ASSERT( DateTime.Invalid.ToString( "yyyy" ) = "" )
	END_TEST

	'' RFC-0006 section 4: a one-character pattern is a NAMED format.
	TEST( constant_formats_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 120 ).WithOffset( 330 )

		'' "o" must be byte-identical to RFC-0005 emission: one implementation,
		'' two entry points.  This is the test that keeps them from drifting.
		CU_ASSERT( d.ToString( "o" ) = d.ToIsoString( ) )
		CU_ASSERT( d.ToString( "O" ) = d.ToIsoString( ) )
		CU_ASSERT( DateTime.MinValue.ToString( "o" ) = DateTime.MinValue.ToIsoString( ) )
		CU_ASSERT( DateTime.MaxValue.ToString( "o" ) = DateTime.MaxValue.ToIsoString( ) )
		CU_ASSERT( DateTime( 2025, 3, 4 ).ToString( "o" ) = DateTime( 2025, 3, 4 ).ToIsoString( ) )

		CU_ASSERT( d.ToString( "s" ) = "2025-03-04T14:30:05" )
		CU_ASSERT( d.ToString( "d" ) = "2025-03-04" )
		CU_ASSERT( d.ToString( "T" ) = "14:30:05" )

		'' "u" and "R" convert to UTC first: 14:30+05:30 is 09:00 UTC
		CU_ASSERT( d.ToString( "u" ) = "2025-03-04 09:00:05Z" )
		CU_ASSERT( d.ToString( "R" ) = "Tue, 04 Mar 2025 09:00:05 GMT" )

		'' RFC 1123 on a UTC value needs no shift
		CU_ASSERT( DateTime( 2025, 3, 4, 9, 0, 5, 0 ).WithOffset( 0 ).ToString( "R" ) = _
		           "Tue, 04 Mar 2025 09:00:05 GMT" )
	END_TEST

	TEST( parse_exact_ )
		dim as DateTime d

		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 14:30:05", "yyyy-MM-dd HH:mm:ss", d ) )
		CU_ASSERT( d.Ticks = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks )

		CU_ASSERT( DateTime.TryParseExact( "04/03/2025", "dd/MM/yyyy", d ) )
		CU_ASSERT( d.Day = 4 andalso d.Month = 3 )

		CU_ASSERT( DateTime.TryParseExact( "Tuesday, 04 March 2025", "dddd, dd MMMM yyyy", d ) )
		CU_ASSERT( d.Day = 4 andalso d.Month = 3 andalso d.Year = 2025 )
		CU_ASSERT( DateTime.TryParseExact( "Tue 04 Mar 2025", "ddd dd MMM yyyy", d ) )
		CU_ASSERT( d.Month = 3 )

		'' names are matched case-insensitively
		CU_ASSERT( DateTime.TryParseExact( "tuesday, 04 MARCH 2025", "dddd, dd MMMM yyyy", d ) )

		'' 12-hour clock
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 02:30 PM", "yyyy-MM-dd hh:mm tt", d ) )
		CU_ASSERT( d.Hour = 14 )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 12:00 AM", "yyyy-MM-dd hh:mm tt", d ) )
		CU_ASSERT( d.Hour = 0 )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 12:00 PM", "yyyy-MM-dd hh:mm tt", d ) )
		CU_ASSERT( d.Hour = 12 )

		'' offsets
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04T14:30:05+05:30", "yyyy-MM-ddTHH:mm:sszzz", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 14:30:05 +05:30", "yyyy-MM-dd HH:mm:ss zzz", d ) )
		CU_ASSERT( d.OffsetMinutes = 330 )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 14:30:05 Z", "yyyy-MM-dd HH:mm:ss K", d ) )
		CU_ASSERT( d.OffsetMinutes = 0 )

		'' day of year decides month and day
		CU_ASSERT( DateTime.TryParseExact( "2025-063", "yyyy-DDD", d ) )
		CU_ASSERT( d.Month = 3 andalso d.Day = 4 )

		'' fields absent from the pattern take their defaults
		CU_ASSERT( DateTime.TryParseExact( "2025", "yyyy", d ) )
		CU_ASSERT( d.Month = 1 andalso d.Day = 1 andalso d.Hour = 0 )

		'' variable-width fields accept one or two digits
		CU_ASSERT( DateTime.TryParseExact( "2025-3-4", "yyyy-M-d", d ) )
		CU_ASSERT( d.Month = 3 andalso d.Day = 4 )
		CU_ASSERT( DateTime.TryParseExact( "2025-12-31", "yyyy-M-d", d ) )
		CU_ASSERT( d.Month = 12 andalso d.Day = 31 )
	END_TEST

	TEST( parse_rejection_ )
		dim as DateTime d

		'' trailing garbage
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04x", "yyyy-MM-dd", d ) = false )
		'' leading garbage
		CU_ASSERT( DateTime.TryParseExact( "x2025-03-04", "yyyy-MM-dd", d ) = false )
		'' missing field
		CU_ASSERT( DateTime.TryParseExact( "2025-03", "yyyy-MM-dd", d ) = false )
		'' wrong separator
		CU_ASSERT( DateTime.TryParseExact( "2025/03/04", "yyyy-MM-dd", d ) = false )
		'' fixed-width MM given one digit
		CU_ASSERT( DateTime.TryParseExact( "2025-3-04", "yyyy-MM-dd", d ) = false )
		'' out-of-range component
		CU_ASSERT( DateTime.TryParseExact( "2025-13-04", "yyyy-MM-dd", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025-02-30", "yyyy-MM-dd", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 25:00", "yyyy-MM-dd HH:mm", d ) = false )
		'' unknown month name
		CU_ASSERT( DateTime.TryParseExact( "Smarch 04 2025", "MMMM dd yyyy", d ) = false )
		'' whitespace is not flexible: the pattern's single space matches one
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04  14:30", "yyyy-MM-dd HH:mm", d ) = false )
		'' empty input
		CU_ASSERT( DateTime.TryParseExact( "", "yyyy-MM-dd", d ) = false )

		'' result is ALWAYS written
		dim as DateTime seeded = DateTime( 2025, 1, 1 )
		CU_ASSERT( DateTime.TryParseExact( "garbage", "yyyy", seeded ) = false )
		CU_ASSERT( seeded.IsValid = false )

		'' RFC-0006 section 5 rule 3: an ambiguous pattern is a PATTERN error,
		'' caught at compile time rather than on the 3rd of December
		CU_ASSERT( DateTime.TryParseExact( "34", "Md", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025034", "yyyyMd", d ) = false )

		'' rule 6: a field repeated with CONFLICTING values fails
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 05", "yyyy-MM-dd MM", d ) = false )
		'' ...but repeated consistently is fine
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 03", "yyyy-MM-dd MM", d ) )

		'' rule 7: a named weekday is cross-checked against the date
		CU_ASSERT( DateTime.TryParseExact( "Monday, 04 March 2025", "dddd, dd MMMM yyyy", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "Tuesday, 04 March 2025", "dddd, dd MMMM yyyy", d ) )

		'' two-digit years are rejected here as they are in RFC-0005
		CU_ASSERT( DateTime.TryParseExact( "25-03-04", "yy-MM-dd", d ) = false )

		'' format-only fields cannot parse
		CU_ASSERT( DateTime.TryParseExact( "1", "Q", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025 10", "yyyy ww", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "Tue, 04 Mar 2025 09:00:05 GMT", "R", d ) = false )
		CU_ASSERT( DateTime.TryParseExact( "2025-03-04 09:00:05Z", "u", d ) = false )
	END_TEST

	'' Round trip through the round-trippable patterns, at the pattern's own
	'' precision.  The truncation is part of the assertion, not an excuse for a
	'' loose comparison.
	TEST( roundtrip_patterns_ )
		dim as ulongint seed = 271828182ull

		for i as integer = 1 to 4000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )

			'' full precision, offset carried
			dim as DateTime a = DateTime.FromTicks( t, 0 )
			dim as DateTime b = DateTime.ParseExact( a.ToString( "o" ), "o" )
			CU_ASSERT( b.IsValid andalso b.Ticks = a.Ticks )

			'' second precision, no offset
			dim as DateTime c = DateTime.FromTicks( t, DT_OFFSET_UNSPECIFIED )
			dim as DateTime e = DateTime.ParseExact( c.ToString( "yyyy-MM-dd HH:mm:ss" ), _
			                                         "yyyy-MM-dd HH:mm:ss" )
			CU_ASSERT( e.IsValid )
			CU_ASSERT( e.Ticks = c.Ticks - ( c.Ticks mod DT_TICKS_PER_SECOND ) )

			'' tick precision via fffffff
			dim as DateTime g = DateTime.ParseExact( c.ToString( "yyyy-MM-dd HH:mm:ss.fffffff" ), _
			                                         "yyyy-MM-dd HH:mm:ss.fffffff" )
			CU_ASSERT( g.IsValid andalso g.Ticks = c.Ticks )

			'' "s" is second precision too
			dim as DateTime h = DateTime.ParseExact( c.ToString( "s" ), "s" )
			CU_ASSERT( h.IsValid )
			CU_ASSERT( h.Ticks = c.Ticks - ( c.Ticks mod DT_TICKS_PER_SECOND ) )
		next
	END_TEST

	'' Invariant English and byte-identical output whatever the machine says.
	TEST( no_locale_leakage_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 120 ).WithOffset( 330 )
		dim as string wantLong = d.ToString( "dddd dd MMMM yyyy" )
		dim as string wantR = d.ToString( "R" )
		dim as string wantFrac = d.ToString( "HH:mm:ss.fff" )

		CU_ASSERT( wantLong = "Tuesday 04 March 2025" )
		CU_ASSERT( wantR = "Tue, 04 Mar 2025 09:00:05 GMT" )

		dim as zstring ptr prev = setlocale( LC_ALL, 0 )
		dim as string saved = ""
		if prev <> 0 then saved = *prev

		setlocale( LC_ALL, "" )
		CU_ASSERT( d.ToString( "dddd dd MMMM yyyy" ) = wantLong )
		CU_ASSERT( d.ToString( "R" ) = wantR )
		CU_ASSERT( d.ToString( "HH:mm:ss.fff" ) = wantFrac )

		setlocale( LC_ALL, "German_Germany" )
		CU_ASSERT( d.ToString( "dddd dd MMMM yyyy" ) = wantLong )
		CU_ASSERT( d.ToString( "R" ) = wantR )
		CU_ASSERT( d.ToString( "HH:mm:ss.fff" ) = wantFrac )

		dim as DateTime p
		CU_ASSERT( DateTime.TryParseExact( "Tuesday 04 March 2025", "dddd dd MMMM yyyy", p ) )
		CU_ASSERT( p.Day = 4 )

		if len( saved ) > 0 then setlocale( LC_ALL, saved )
	END_TEST

END_SUITE
