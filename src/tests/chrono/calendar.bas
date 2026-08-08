'' Calendar arithmetic and utilities -- C:\dev\docs\datetime\RFC-0004-calendar.md s5.

#include once "fbcunit.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.calendar )

	'' RFC-0004 section 2, the end-of-month rule.
	TEST( end_of_month_clamping_ )
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 1 ).Month = 2 )
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 1 ).Day = 28 )
		CU_ASSERT( DateTime( 2024, 1, 31 ).AddMonths( 1 ).Day = 29 )   '' leap
		CU_ASSERT( DateTime( 2025, 3, 31 ).AddMonths( -1 ).Day = 28 )
		CU_ASSERT( DateTime( 2024, 2, 29 ).AddYears( 1 ).Day = 28 )
		CU_ASSERT( DateTime( 2024, 2, 29 ).AddYears( 4 ).Day = 29 )
		CU_ASSERT( DateTime( 2025, 5, 31 ).AddMonths( 1 ).Day = 30 )

		'' Clamping is LOSSY, and this test exists so that a future "fix" which
		'' restores the original day has to argue with RFC-0004 first.
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 1 ).AddMonths( -1 ).Day = 28 )

		'' ...and NOT associative.  31 January is the case that differs; note
		'' 31 December does NOT (both routes land on 28 February).
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 2 ).Day = 31 )
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 1 ).AddMonths( 1 ).Day = 28 )
		CU_ASSERT( DateTime( 2024, 12, 31 ).AddMonths( 2 ).Day = 28 )
		CU_ASSERT( DateTime( 2024, 12, 31 ).AddMonths( 1 ).AddMonths( 1 ).Day = 28 )

		'' time of day and offset ride through untouched
		dim as DateTime t = DateTime( 2025, 1, 31, 14, 30, 5, 123 ).WithOffset( 330 )
		dim as DateTime r = t.AddMonths( 1 )
		CU_ASSERT( r.Hour = 14 )
		CU_ASSERT( r.Minute = 30 )
		CU_ASSERT( r.Second = 5 )
		CU_ASSERT( r.Millisecond = 123 )
		CU_ASSERT( r.OffsetMinutes = 330 )

		'' zero is identity
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddMonths( 0 ).Ticks = DateTime( 2025, 1, 31 ).Ticks )
	END_TEST

	'' Every month end of a leap and a non-leap year, against a spread of n.
	TEST( clamping_table_ )
		dim as long offs( 0 to 8 ) = { -13, -12, -2, -1, 0, 1, 2, 12, 13 }
		dim as long yrs( 0 to 1 ) = { 2024, 2025 }

		for yi as integer = 0 to 1
			dim as long y = yrs( yi )
			for m as long = 1 to 12
				dim as long last = DateTime.DaysInMonth( y, m )
				dim as DateTime src = DateTime( y, m, last )
				CU_ASSERT( src.IsValid )
				for oi as integer = 0 to 8
					dim as DateTime got = src.AddMonths( offs( oi ) )
					CU_ASSERT( got.IsValid )
					'' The day is the source day, clamped to the target month.
					'' NOTE a month-end source does NOT always stay a month end:
					'' 29 Feb + 1 month is 29 March, not 31 March.
					dim as long want = last
					dim as long targetLast = DateTime.DaysInMonth( got.Year, got.Month )
					if want > targetLast then want = targetLast
					CU_ASSERT( got.Day = want )
					'' and lands on the month the arithmetic says it should
					dim as longint total = clngint( y ) * 12 + ( m - 1 ) + offs( oi )
					CU_ASSERT( got.Year = clng( total \ 12 ) )
					CU_ASSERT( got.Month = clng( total mod 12 ) + 1 )
				next
			next
		next
	END_TEST

	'' AddYears( n ) must be exactly AddMonths( n * 12 ) so the clamp lives once.
	TEST( addyears_is_addmonths12_ )
		dim as long ns( 0 to 7 ) = { -400, -100, -4, -1, 1, 4, 100, 400 }
		dim as long ds( 0 to 4 ) = { 1, 28, 29, 30, 31 }

		for mi as long = 1 to 12
			for di as integer = 0 to 4
				if ds( di ) > DateTime.DaysInMonth( 2024, mi ) then continue for
				dim as DateTime src = DateTime( 2024, mi, ds( di ) )
				CU_ASSERT( src.IsValid )
				for ni as integer = 0 to 7
					dim as DateTime a = src.AddYears( ns( ni ) )
					dim as DateTime b = src.AddMonths( ns( ni ) * 12 )
					CU_ASSERT( a.IsValid = b.IsValid )
					if a.IsValid then CU_ASSERT( a.Ticks = b.Ticks )
				next
			next
		next
	END_TEST

	TEST( calendar_utilities_ )
		CU_ASSERT( DateTime.IsLeapYear( 2024 ) )
		CU_ASSERT( DateTime.IsLeapYear( 2000 ) )
		CU_ASSERT( DateTime.IsLeapYear( 1900 ) = false )
		CU_ASSERT( DateTime.IsLeapYear( 2100 ) = false )
		CU_ASSERT( DateTime.IsLeapYear( 2025 ) = false )

		CU_ASSERT( DateTime.DaysInMonth( 2024, 2 ) = 29 )
		CU_ASSERT( DateTime.DaysInMonth( 2025, 2 ) = 28 )
		CU_ASSERT( DateTime.DaysInMonth( 2025, 4 ) = 30 )
		CU_ASSERT( DateTime.DaysInMonth( 2025, 12 ) = 31 )
		CU_ASSERT( DateTime.DaysInYear( 2024 ) = 366 )
		CU_ASSERT( DateTime.DaysInYear( 2025 ) = 365 )
		CU_ASSERT( DateTime.WeeksInYear( 2020 ) = 53 )
		CU_ASSERT( DateTime.WeeksInYear( 2025 ) = 52 )

		CU_ASSERT( DateTime( 2025, 1, 1 ).Quarter = 1 )
		CU_ASSERT( DateTime( 2025, 3, 31 ).Quarter = 1 )
		CU_ASSERT( DateTime( 2025, 4, 1 ).Quarter = 2 )
		CU_ASSERT( DateTime( 2025, 7, 1 ).Quarter = 3 )
		CU_ASSERT( DateTime( 2025, 10, 1 ).Quarter = 4 )
		CU_ASSERT( DateTime( 2025, 12, 31 ).Quarter = 4 )

		CU_ASSERT( DateTime( 2025, 3, 1 ).IsFirstDayOfMonth )
		CU_ASSERT( DateTime( 2025, 3, 2 ).IsFirstDayOfMonth = false )
		CU_ASSERT( DateTime( 2025, 3, 31 ).IsLastDayOfMonth )
		CU_ASSERT( DateTime( 2024, 2, 29 ).IsLastDayOfMonth )
		CU_ASSERT( DateTime( 2024, 2, 28 ).IsLastDayOfMonth = false )
	END_TEST

	'' The hard ISO-week cases: dates whose ISO week-year differs from Year.
	'' Using Year instead of IsoWeekYear to render a week date is THE classic
	'' bug in this area.
	TEST( iso_week_ )
		CU_ASSERT( DateTime( 2025, 12, 29 ).IsoWeek = 1 )
		CU_ASSERT( DateTime( 2025, 12, 29 ).IsoWeekYear = 2026 )
		CU_ASSERT( DateTime( 2021, 1, 1 ).IsoWeek = 53 )
		CU_ASSERT( DateTime( 2021, 1, 1 ).IsoWeekYear = 2020 )
		CU_ASSERT( DateTime( 2016, 1, 3 ).IsoWeek = 53 )
		CU_ASSERT( DateTime( 2016, 1, 3 ).IsoWeekYear = 2015 )
		CU_ASSERT( DateTime( 2000, 1, 1 ).IsoWeek = 52 )
		CU_ASSERT( DateTime( 2000, 1, 1 ).IsoWeekYear = 1999 )
		CU_ASSERT( DateTime( 2025, 3, 4 ).IsoWeek = 10 )
		CU_ASSERT( DateTime( 2025, 3, 4 ).IsoWeekYear = 2025 )

		'' LocalDate agrees with DateTime
		CU_ASSERT( LocalDate( 2025, 12, 29 ).IsoWeek = 1 )
		CU_ASSERT( LocalDate( 2025, 12, 29 ).IsoWeekYear = 2026 )
	END_TEST

	TEST( boundary_helpers_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )

		CU_ASSERT( d.StartOfDay( ).TickOfDay = 0 )
		CU_ASSERT( d.EndOfDay( ).TickOfDay = DT_TICKS_PER_DAY - 1 )
		CU_ASSERT( d.StartOfDay( ).Ticks <= d.Ticks )
		CU_ASSERT( d.Ticks <= d.EndOfDay( ).Ticks )
		CU_ASSERT( d.StartOfDay( ).Day = 4 )
		CU_ASSERT( d.EndOfDay( ).Day = 4 )

		CU_ASSERT( d.StartOfMonth( ).Day = 1 )
		CU_ASSERT( d.EndOfMonth( ).Day = 31 )
		CU_ASSERT( d.StartOfYear( ).Month = 1 )
		CU_ASSERT( d.StartOfYear( ).Day = 1 )
		CU_ASSERT( d.EndOfYear( ).Month = 12 )
		CU_ASSERT( d.EndOfYear( ).Day = 31 )

		'' the identity RFC-0004 section 5 names
		CU_ASSERT( d.EndOfMonth( ).AddTicks( 1 ).Ticks = d.StartOfMonth( ).AddMonths( 1 ).Ticks )

		'' February, so a leap year actually matters
		CU_ASSERT( DateTime( 2024, 2, 10 ).EndOfMonth( ).Day = 29 )
		CU_ASSERT( DateTime( 2025, 2, 10 ).EndOfMonth( ).Day = 28 )

		'' StartOfWeek lands on the requested weekday, for all seven
		for fd as long = DT_MONDAY to DT_SUNDAY
			dim as DateTime s = d.StartOfWeek( fd )
			CU_ASSERT( s.IsValid )
			CU_ASSERT( s.DayOfWeek = fd )
			CU_ASSERT( s.Ticks <= d.Ticks )
			CU_ASSERT( ( d - s ).TotalDays < 7 )
			CU_ASSERT( s.TickOfDay = 0 )
		next
		CU_ASSERT( d.StartOfWeek( 0 ).IsValid = false )
		CU_ASSERT( d.StartOfWeek( 8 ).IsValid = false )

		'' Next/Prev land on the right weekday and are STRICTLY later/earlier --
		'' already being on that weekday means a full week, not a no-op.
		for w as long = DT_MONDAY to DT_SUNDAY
			dim as DateTime n = d.NextWeekday( w )
			dim as DateTime p = d.PrevWeekday( w )
			CU_ASSERT( n.DayOfWeek = w )
			CU_ASSERT( p.DayOfWeek = w )
			CU_ASSERT( n.Ticks > d.Ticks )
			CU_ASSERT( p.Ticks < d.Ticks )
			CU_ASSERT( ( n - d ).TotalDays <= 7 )
			CU_ASSERT( ( d - p ).TotalDays <= 7 )
		next
		CU_ASSERT( ( d.NextWeekday( d.DayOfWeek ) - d ).TotalDays = 7 )
		CU_ASSERT( ( d - d.PrevWeekday( d.DayOfWeek ) ).TotalDays = 7 )
	END_TEST

	TEST( julian_day_ )
		'' the standard anchor
		CU_ASSERT( DateTime( 2000, 1, 1 ).JulianDayNumber = 2451545 )
		CU_ASSERT( abs( DateTime( 2000, 1, 1, 12, 0, 0, 0 ).JulianDay - 2451545.0 ) < 0.0000001 )
		CU_ASSERT( DateTime( 1, 1, 1 ).JulianDayNumber = 1721426 )

		'' round trip over a spread of dates
		dim as ulongint seed = 987654321ull
		for i as integer = 1 to 2000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )
			dim as DateTime a = DateTime.FromTicks( t, DT_OFFSET_UNSPECIFIED ).StartOfDay( )
			dim as DateTime b = DateTime.FromJulianDay( a.JulianDay )
			CU_ASSERT( b.IsValid )
			CU_ASSERT( b.GetDate( ).DayNumber = a.GetDate( ).DayNumber )
		next

		'' JD 0 is 4713 BC, far outside the range
		CU_ASSERT( DateTime.FromJulianDay( 0.0 ).IsValid = false )
		CU_ASSERT( DateTime.FromJulianDay( 1e30 ).IsValid = false )
	END_TEST

	'' RFC-0004 section 4: never wraps, never clamps to the range ends.
	TEST( calendar_overflow_ )
		CU_ASSERT( DateTime( 9999, 12, 31 ).AddMonths( 1 ).IsValid = false )
		CU_ASSERT( DateTime( 9999, 1, 1 ).AddYears( 1 ).IsValid = false )
		CU_ASSERT( DateTime( 1, 1, 1 ).AddMonths( -1 ).IsValid = false )
		CU_ASSERT( DateTime( 1, 1, 1 ).AddYears( -1 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1 ).AddMonths( 2000000 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1 ).AddMonths( -2000000 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1 ).AddYears( 2147483647 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1 ).AddYears( -2147483647 ).IsValid = false )

		'' the very edges still work
		CU_ASSERT( DateTime( 9999, 12, 31 ).AddMonths( 0 ).IsValid )
		CU_ASSERT( DateTime( 9999, 11, 30 ).AddMonths( 1 ).IsValid )
		CU_ASSERT( DateTime( 1, 2, 1 ).AddMonths( -1 ).IsValid )

		'' Invalid is absorbing here too
		CU_ASSERT( DateTime.Invalid.AddMonths( 1 ).IsValid = false )
		CU_ASSERT( DateTime.Invalid.StartOfMonth( ).IsValid = false )
		CU_ASSERT( DateTime.Invalid.NextWeekday( DT_MONDAY ).IsValid = false )
		CU_ASSERT( DateTime.Invalid.IsoWeek = 0 )
	END_TEST

	TEST( localdate_calendar_ )
		CU_ASSERT( LocalDate( 2025, 1, 31 ).AddMonths( 1 ).Day = 28 )
		CU_ASSERT( LocalDate( 2024, 1, 31 ).AddMonths( 1 ).Day = 29 )
		CU_ASSERT( LocalDate( 2024, 2, 29 ).AddYears( 1 ).Day = 28 )
		CU_ASSERT( LocalDate( 2025, 3, 4 ).StartOfMonth( ).Day = 1 )
		CU_ASSERT( LocalDate( 2025, 3, 4 ).EndOfMonth( ).Day = 31 )
		CU_ASSERT( LocalDate( 2024, 2, 4 ).EndOfMonth( ).Day = 29 )
		CU_ASSERT( LocalDate( 2025, 3, 4 ).Quarter = 1 )
		CU_ASSERT( LocalDate( 2025, 3, 1 ).IsFirstDayOfMonth )
		CU_ASSERT( LocalDate( 2025, 3, 31 ).IsLastDayOfMonth )
		CU_ASSERT( LocalDate.MaxValue.AddMonths( 1 ).IsValid = false )
		CU_ASSERT( LocalDate.MinValue.AddMonths( -1 ).IsValid = false )
		CU_ASSERT( LocalDate.Invalid.AddMonths( 1 ).IsValid = false )

		'' DateTime and LocalDate must agree
		for m as long = 1 to 12
			dim as long last = DateTime.DaysInMonth( 2025, m )
			CU_ASSERT( DateTime( 2025, m, last ).AddMonths( 5 ).Day = _
			           LocalDate( 2025, m, last ).AddMonths( 5 ).Day )
		next
	END_TEST

END_SUITE
