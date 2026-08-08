'' ISO 8601 / RFC 3339 -- docs/datetime/RFC-0005-iso8601.md section 6.
''
'' Everything here asserts EXACT strings in both directions.  That is possible
'' precisely because this layer is locale-independent by construction, and it
'' is why RFC-0005 outranks the general pattern formatter.

#include once "fbcunit.bi"
#include once "crt/locale.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.iso )

	TEST( emit_datetime_ )
		'' no fraction when the sub-second part is zero
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).ToIsoString( ) = "2025-03-04T14:30:05" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 0 ).ToIsoString( ) = "2025-03-04T14:30:05Z" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 330 ).ToIsoString( ) = "2025-03-04T14:30:05+05:30" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( -300 ).ToIsoString( ) = "2025-03-04T14:30:05-05:00" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 345 ).ToIsoString( ) = "2025-03-04T14:30:05+05:45" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 1080 ).ToIsoString( ) = "2025-03-04T14:30:05+18:00" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( -1080 ).ToIsoString( ) = "2025-03-04T14:30:05-18:00" )

		'' exactly seven digits when non-zero, and NOT trimmed
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 123 ).ToIsoString( ) = "2025-03-04T14:30:05.1230000" )
		CU_ASSERT( DateTime.FromTicks( DateTime( 2025, 1, 1 ).Ticks + 1, DT_OFFSET_UNSPECIFIED ).ToIsoString( ) = _
		           "2025-01-01T00:00:00.0000001" )
		CU_ASSERT( DateTime.FromTicks( DateTime( 2025, 1, 1 ).Ticks + 1000000, DT_OFFSET_UNSPECIFIED ).ToIsoString( ) = _
		           "2025-01-01T00:00:00.1000000" )

		'' the range ends, four-digit year at both
		CU_ASSERT( DateTime.MinValue.ToIsoString( ) = "0001-01-01T00:00:00" )
		CU_ASSERT( DateTime.MaxValue.ToIsoString( ) = "9999-12-31T23:59:59.9999999" )
		CU_ASSERT( DateTime( 1, 1, 1 ).WithOffset( 0 ).ToIsoString( ) = "0001-01-01T00:00:00Z" )

		'' single-digit month/day/hour are zero-padded
		CU_ASSERT( DateTime( 2025, 1, 2, 3, 4, 5, 0 ).ToIsoString( ) = "2025-01-02T03:04:05" )

		'' Invalid emits the empty string (RFC-0001 s3 rule 5)
		CU_ASSERT( DateTime.Invalid.ToIsoString( ) = "" )
		CU_ASSERT( Instant.Invalid.ToIsoString( ) = "" )
		CU_ASSERT( LocalDate.Invalid.ToIsoString( ) = "" )
		CU_ASSERT( LocalTime.Invalid.ToIsoString( ) = "" )

		'' ToString is ToIsoString
		CU_ASSERT( DateTime( 2025, 3, 4 ).ToString( ) = DateTime( 2025, 3, 4 ).ToIsoString( ) )
	END_TEST

	TEST( emit_other_types_ )
		CU_ASSERT( Instant.FromTicks( DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks ).ToIsoString( ) = _
		           "2025-03-04T14:30:05Z" )
		CU_ASSERT( Instant.MinValue.ToIsoString( ) = "0001-01-01T00:00:00Z" )

		CU_ASSERT( LocalDate( 2025, 3, 4 ).ToIsoString( ) = "2025-03-04" )
		CU_ASSERT( LocalDate( 1, 1, 1 ).ToIsoString( ) = "0001-01-01" )
		CU_ASSERT( LocalDate( 9999, 12, 31 ).ToIsoString( ) = "9999-12-31" )

		CU_ASSERT( LocalTime( 14, 30, 5, 0 ).ToIsoString( ) = "14:30:05" )
		CU_ASSERT( LocalTime( 0, 0, 0, 0 ).ToIsoString( ) = "00:00:00" )
		CU_ASSERT( LocalTime( 14, 30, 5, 123 ).ToIsoString( ) = "14:30:05.1230000" )
		CU_ASSERT( LocalTime.MaxValue.ToIsoString( ) = "23:59:59.9999999" )
	END_TEST

	'' RFC-0005 section 5.  Note the duration fraction IS trimmed, unlike the
	'' timestamp forms -- durations are not sorted as strings.
	TEST( emit_duration_ )
		CU_ASSERT( TimeSpan.Zero.ToIsoString( ) = "PT0S" )
		CU_ASSERT( TimeSpan( 1, 2, 3, 4, 500 ).ToIsoString( ) = "P1DT2H3M4.5S" )
		CU_ASSERT( TimeSpan.FromDays( 1 ).ToIsoString( ) = "P1D" )
		CU_ASSERT( TimeSpan.FromHours( 2 ).ToIsoString( ) = "PT2H" )
		CU_ASSERT( TimeSpan.FromMinutes( 3 ).ToIsoString( ) = "PT3M" )
		CU_ASSERT( TimeSpan.FromSeconds( 4 ).ToIsoString( ) = "PT4S" )
		CU_ASSERT( TimeSpan.FromHours( -1.5 ).ToIsoString( ) = "-PT1H30M" )
		CU_ASSERT( TimeSpan.FromTicks( 1 ).ToIsoString( ) = "PT0.0000001S" )
		CU_ASSERT( TimeSpan.FromMilliseconds( 1500 ).ToIsoString( ) = "PT1.5S" )
		CU_ASSERT( TimeSpan.Invalid.ToIsoString( ) = "" )
	END_TEST

	'' Every production in RFC-0005 section 2.
	TEST( parse_accepted_forms_ )
		dim as DateTime d
		dim as longint want = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks

		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05Z", d ) )
		CU_ASSERT( d.Ticks = want andalso d.OffsetMinutes = 0 )

		'' basic format
		CU_ASSERT( DateTime.TryParseIso( "20250304T143005Z", d ) )
		CU_ASSERT( d.Ticks = want )

		'' ordinal date -- 4 March is day 63
		CU_ASSERT( DateTime.TryParseIso( "2025-063T14:30:05Z", d ) )
		CU_ASSERT( d.Ticks = want )
		CU_ASSERT( DateTime.TryParseIso( "2025063T143005Z", d ) )
		CU_ASSERT( d.Ticks = want )

		'' ISO week date -- 2025-W10-2 is 4 March
		CU_ASSERT( DateTime.TryParseIso( "2025-W10-2", d ) )
		CU_ASSERT( d.Year = 2025 andalso d.Month = 3 andalso d.Day = 4 )
		CU_ASSERT( DateTime.TryParseIso( "2025W102", d ) )
		CU_ASSERT( d.Month = 3 andalso d.Day = 4 )

		'' comma is the ISO 8601 preferred decimal separator
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05,5Z", d ) )
		CU_ASSERT( d.Ticks = want + 5000000 )

		'' RFC 3339 s5.6 space separator -- what every SQL database emits
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04 14:30:05Z", d ) )
		CU_ASSERT( d.Ticks = want )

		'' lowercase t and z
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04t14:30:05z", d ) )
		CU_ASSERT( d.Ticks = want )

		'' offset spellings
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05+05", d ) )
		CU_ASSERT( d.OffsetMinutes = 300 )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05+0530", d ) )
		CU_ASSERT( d.OffsetMinutes = 330 )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05-05:30", d ) )
		CU_ASSERT( d.OffsetMinutes = -330 )

		'' no offset at all -> unspecified, NOT UTC
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05", d ) )
		CU_ASSERT( d.OffsetMinutes = DT_OFFSET_UNSPECIFIED )
		CU_ASSERT( d.HasOffset = false )

		'' date only
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04", d ) )
		CU_ASSERT( d.TickOfDay = 0 )

		'' minutes-only and hour-only times
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30Z", d ) )
		CU_ASSERT( d.Hour = 14 andalso d.Minute = 30 andalso d.Second = 0 )

		'' surrounding whitespace is trimmed
		CU_ASSERT( DateTime.TryParseIso( "  2025-03-04T14:30:05Z  ", d ) )
		CU_ASSERT( d.Ticks = want )

		'' leap day, both directions
		CU_ASSERT( DateTime.TryParseIso( "2024-02-29", d ) )
		CU_ASSERT( d.Day = 29 )
	END_TEST

	'' Fractional digits: 1..7 significant, more TRUNCATED (not rounded, not
	'' rejected) so nanosecond output from Go or Rust still parses.
	TEST( parse_fractions_ )
		dim as DateTime d
		dim as longint bas = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks

		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05.1Z", d ) )
		CU_ASSERT( d.Ticks = bas + 1000000 )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05.1234567Z", d ) )
		CU_ASSERT( d.Ticks = bas + 1234567 )
		'' 8 and 9 digits truncate, they do not round
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05.12345678Z", d ) )
		CU_ASSERT( d.Ticks = bas + 1234567 )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05.123456789Z", d ) )
		CU_ASSERT( d.Ticks = bas + 1234567 )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05.99999999Z", d ) )
		CU_ASSERT( d.Ticks = bas + 9999999 )
	END_TEST

	'' RFC-0005 section 3: TryParse returns false AND writes Invalid, so a
	'' caller who ignores the return value cannot read a stale value.
	TEST( parse_rejection_corpus_ )
		dim as DateTime d
		dim as string bad( 0 to 33 ) = { _
			"", " ", "   ", _
			"2025-13-01", "2025-00-01", "2025-01-00", "2025-01-32", _
			"2025-02-30", "2025-02-29", "1900-02-29", "2100-02-29", _
			"2025-04-31", _
			"25-03-04", "225-03-04", "20250-03-04", _
			"2025-03-04T24:00:00", "2025-03-04T23:59:60", "2025-03-04T25:00:00", _
			"2025-03-04T14:60:00", _
			"2025-03-04T14:30:05+19:00", "2025-03-04T14:30:05-19:00", _
			"2025-03-04T14:30:05+05:70", _
			"2025-03-04T14:30:05Zx", "2025-03-04xx", "x2025-03-04", _
			"2025-03-04T", "T14:30:05", "2025-03-04T14:30:05.", _
			"+002025-03-04", "-2025-03-04", _
			"2025-W54-1", "2025-W00-1", "2025-367", "2025-000" }

		for i as integer = 0 to 33
			dim as DateTime r = DateTime( 2025, 1, 1 )    '' pre-seed with a valid value
			CU_ASSERT( DateTime.TryParseIso( bad( i ), r ) = false )
			'' result is ALWAYS written, so the stale value is gone
			CU_ASSERT( r.IsValid = false )
			CU_ASSERT( DateTime.ParseIso( bad( i ) ).IsValid = false )
		next

		'' the controls: each of these must PASS
		CU_ASSERT( DateTime.TryParseIso( "2024-02-29", d ) )
		CU_ASSERT( DateTime.TryParseIso( "2000-02-29", d ) )
		CU_ASSERT( DateTime.TryParseIso( "2025-W01-1", d ) )
		CU_ASSERT( DateTime.TryParseIso( "2025-365", d ) )
		CU_ASSERT( DateTime.TryParseIso( "2024-366", d ) )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05+18:00", d ) )
	END_TEST

	'' An Instant needs an offset; a DateTime does not.  The type system doing
	'' its job, asserted as a pair.
	TEST( instant_requires_offset_ )
		dim as Instant i
		dim as DateTime d

		CU_ASSERT( Instant.TryParseIso( "2025-03-04T14:30:05", i ) = false )
		CU_ASSERT( i.IsValid = false )
		CU_ASSERT( DateTime.TryParseIso( "2025-03-04T14:30:05", d ) )

		CU_ASSERT( Instant.TryParseIso( "2025-03-04T14:30:05Z", i ) )
		CU_ASSERT( i.Ticks = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).Ticks )

		'' an offset instant is normalised back to UTC
		CU_ASSERT( Instant.TryParseIso( "2025-03-04T14:30:05+01:00", i ) )
		CU_ASSERT( i.Ticks = DateTime( 2025, 3, 4, 13, 30, 5, 0 ).Ticks )
	END_TEST

	TEST( parse_other_types_ )
		dim as LocalDate ld
		dim as LocalTime lt

		CU_ASSERT( LocalDate.TryParseIso( "2025-03-04", ld ) )
		CU_ASSERT( ld.Year = 2025 andalso ld.Month = 3 andalso ld.Day = 4 )
		CU_ASSERT( LocalDate.TryParseIso( "20250304", ld ) )
		CU_ASSERT( ld.Day = 4 )
		CU_ASSERT( LocalDate.TryParseIso( "2025-03-04T00:00:00", ld ) = false )
		CU_ASSERT( LocalDate.TryParseIso( "2025-02-30", ld ) = false )

		CU_ASSERT( LocalTime.TryParseIso( "14:30:05", lt ) )
		CU_ASSERT( lt.Hour = 14 andalso lt.Minute = 30 andalso lt.Second = 5 )
		CU_ASSERT( LocalTime.TryParseIso( "143005", lt ) )
		CU_ASSERT( lt.Second = 5 )
		CU_ASSERT( LocalTime.TryParseIso( "14:30", lt ) )
		CU_ASSERT( lt.Minute = 30 )
		CU_ASSERT( LocalTime.TryParseIso( "24:00:00", lt ) = false )
		CU_ASSERT( LocalTime.TryParseIso( "14:30:05Z", lt ) = false )
	END_TEST

	TEST( duration_grammar_ )
		dim as TimeSpan t

		CU_ASSERT( TimeSpan.TryParseIso( "PT0S", t ) andalso t.Ticks = 0 )
		CU_ASSERT( TimeSpan.TryParseIso( "P1DT2H3M4.5S", t ) )
		CU_ASSERT( t.Ticks = TimeSpan( 1, 2, 3, 4, 500 ).Ticks )
		CU_ASSERT( TimeSpan.TryParseIso( "P1D", t ) andalso t.TotalDays = 1 )
		CU_ASSERT( TimeSpan.TryParseIso( "PT2H", t ) andalso t.TotalHours = 2 )
		CU_ASSERT( TimeSpan.TryParseIso( "PT1M", t ) andalso t.TotalMinutes = 1 )
		CU_ASSERT( TimeSpan.TryParseIso( "-PT1H30M", t ) andalso t.TotalHours = -1.5 )
		CU_ASSERT( TimeSpan.TryParseIso( "PT4,5S", t ) andalso t.Ticks = 45000000 )

		'' weeks accepted on input, converted to days, never emitted
		CU_ASSERT( TimeSpan.TryParseIso( "P2W", t ) andalso t.TotalDays = 14 )
		CU_ASSERT( t.ToIsoString( ) = "P14D" )

		'' years and months REJECTED: a TimeSpan is a fixed duration and a
		'' month has no fixed length
		CU_ASSERT( TimeSpan.TryParseIso( "P1Y", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "P1M", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "P1Y2M", t ) = false )
		'' ...but M AFTER the T is minutes, and is fine
		CU_ASSERT( TimeSpan.TryParseIso( "PT1M", t ) )

		'' malformed
		CU_ASSERT( TimeSpan.TryParseIso( "P", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "1D", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "PD", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "PT", t ) = false )
		CU_ASSERT( TimeSpan.TryParseIso( "P1H", t ) = false )     '' H needs T
		CU_ASSERT( TimeSpan.TryParseIso( "PT1D", t ) = false )    '' D before T
		CU_ASSERT( TimeSpan.TryParseIso( "P1.5D", t ) = false )   '' fraction only on S
		CU_ASSERT( TimeSpan.TryParseIso( "P1DX", t ) = false )
	END_TEST

	'' RFC-0005 section 4: ParseIso( v.ToIsoString( ) ) = v, exactly, for every
	'' valid value.  Fixed seed so a failure reproduces.
	TEST( roundtrip_exhaustive_ )
		dim as ulongint seed = 3141592653ull
		dim as short offs( 0 to 7 ) = { 0, DT_OFFSET_UNSPECIFIED, -1080, -300, _
		                                0, 330, 345, 1080 }

		for i as integer = 1 to 12500
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )

			for k as integer = 0 to 7
				dim as DateTime a = DateTime.FromTicks( t, offs( k ) )
				if a.IsValid = false then continue for
				dim as DateTime b = DateTime.ParseIso( a.ToIsoString( ) )
				CU_ASSERT( b.IsValid )
				CU_ASSERT( b.Ticks = a.Ticks )
				CU_ASSERT( b.OffsetMinutes = a.OffsetMinutes )
			next
		next
	END_TEST

	'' Emission is canonical, so a second round is a fixed point even though
	'' the FIRST round normalises basic format, ordinal dates and commas.
	TEST( string_fixed_point_ )
		dim as string src( 0 to 11 ) = { _
			"20250304T143005Z", "2025-063T14:30:05Z", "2025-W10-2", _
			"2025-03-04T14:30:05,5Z", "2025-03-04 14:30:05Z", _
			"2025-03-04t14:30:05z", "2025-03-04T14:30:05+05", _
			"2025-03-04T14:30:05+0530", "2025-03-04T14:30:05.123456789Z", _
			"2025-03-04", "2025-03-04T14:30Z", "  2025-03-04T14:30:05Z  " }

		for i as integer = 0 to 11
			dim as string s2 = DateTime.ParseIso( src( i ) ).ToIsoString( )
			dim as string s3 = DateTime.ParseIso( s2 ).ToIsoString( )
			CU_ASSERT( len( s2 ) > 0 )
			CU_ASSERT( s2 = s3 )
		next

		'' durations too
		dim as string ds( 0 to 4 ) = { "P2W", "PT4,5S", "P1DT2H3M4.5S", "PT0S", "-PT1H30M" }
		for i as integer = 0 to 4
			dim as string s2 = TimeSpan.ParseIso( ds( i ) ).ToIsoString( )
			dim as string s3 = TimeSpan.ParseIso( s2 ).ToIsoString( )
			CU_ASSERT( s2 = s3 )
		next
	END_TEST

	'' The test that catches an accidental locale-dependent conversion -- a
	'' comma decimal point on a European machine is a real and easy bug.
	TEST( no_locale_leakage_ )
		dim as string want = DateTime( 2025, 3, 4, 14, 30, 5, 123 ).WithOffset( 330 ).ToIsoString( )
		dim as string wantDur = TimeSpan( 1, 2, 3, 4, 500 ).ToIsoString( )

		dim as zstring ptr prev = setlocale( LC_ALL, 0 )
		dim as string saved = ""
		if prev <> 0 then saved = *prev

		'' whatever the machine offers; the assertions hold either way
		setlocale( LC_ALL, "" )
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 123 ).WithOffset( 330 ).ToIsoString( ) = want )
		CU_ASSERT( TimeSpan( 1, 2, 3, 4, 500 ).ToIsoString( ) = wantDur )

		setlocale( LC_ALL, "German_Germany" )      '' comma decimal separator
		CU_ASSERT( DateTime( 2025, 3, 4, 14, 30, 5, 123 ).WithOffset( 330 ).ToIsoString( ) = want )
		CU_ASSERT( TimeSpan( 1, 2, 3, 4, 500 ).ToIsoString( ) = wantDur )

		dim as DateTime d
		CU_ASSERT( DateTime.TryParseIso( want, d ) )
		CU_ASSERT( d.ToIsoString( ) = want )

		if len( saved ) > 0 then setlocale( LC_ALL, saved )
	END_TEST

END_SUITE
