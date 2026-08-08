'' DateTime / LocalDate / LocalTime / Instant
'' C:\dev\docs\datetime\RFC-0001-core-representation.md section 6.

#include once "fbcunit.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.core )

	TEST( datetime_components_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )
		CU_ASSERT( d.IsValid )
		CU_ASSERT( d.Year = 2025 )
		CU_ASSERT( d.Month = 3 )
		CU_ASSERT( d.Day = 4 )
		CU_ASSERT( d.Hour = 14 )
		CU_ASSERT( d.Minute = 30 )
		CU_ASSERT( d.Second = 5 )
		CU_ASSERT( d.Millisecond = 123 )
		CU_ASSERT( d.Microsecond = 123000 )
		CU_ASSERT( d.DayOfWeek = DT_TUESDAY )
		CU_ASSERT( d.DayOfYear = 63 )
		CU_ASSERT( d.TickOfDay = 14 * DT_TICKS_PER_HOUR + 30 * DT_TICKS_PER_MINUTE + _
		                         5 * DT_TICKS_PER_SECOND + 123 * DT_TICKS_PER_MILLISECOND )

		'' the date-only constructor zeroes the time
		dim as DateTime m = DateTime( 2025, 3, 4 )
		CU_ASSERT( m.Hour = 0 )
		CU_ASSERT( m.Minute = 0 )
		CU_ASSERT( m.Second = 0 )
		CU_ASSERT( m.TickOfDay = 0 )
	END_TEST

	TEST( range_boundaries_ )
		CU_ASSERT( DateTime.MinValue.Ticks = DT_MIN_TICKS )
		CU_ASSERT( DateTime.MaxValue.Ticks = DT_MAX_TICKS )
		CU_ASSERT( DateTime.MinValue.Year = 1 )
		CU_ASSERT( DateTime.MinValue.Month = 1 )
		CU_ASSERT( DateTime.MinValue.Day = 1 )
		CU_ASSERT( DateTime.MinValue.DayOfWeek = DT_MONDAY )
		CU_ASSERT( DateTime.MaxValue.Year = 9999 )
		CU_ASSERT( DateTime.MaxValue.Month = 12 )
		CU_ASSERT( DateTime.MaxValue.Day = 31 )
		CU_ASSERT( DateTime.MaxValue.Hour = 23 )
		CU_ASSERT( DateTime.MaxValue.Minute = 59 )
		CU_ASSERT( DateTime.MaxValue.Second = 59 )

		CU_ASSERT( DateTime( 1, 1, 1 ).IsValid )
		CU_ASSERT( DateTime( 9999, 12, 31 ).IsValid )
	END_TEST

	'' Out-of-range construction yields Invalid: no clamping, no normalizing,
	'' no ERR().  RFC-0001 section 3 rule 1.
	TEST( invalid_construction_ )
		CU_ASSERT( DateTime( 2025, 0, 1 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 13, 1 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 0 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 32 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 2, 30 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 4, 31 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 2, 29 ).IsValid = false )
		CU_ASSERT( DateTime( 1900, 2, 29 ).IsValid = false )
		CU_ASSERT( DateTime( 2100, 2, 29 ).IsValid = false )
		CU_ASSERT( DateTime( 0, 1, 1 ).IsValid = false )
		CU_ASSERT( DateTime( 10000, 1, 1 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1, 24, 0, 0, 0 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1, -1, 0, 0, 0 ).IsValid = false )
		CU_ASSERT( DateTime( 2025, 1, 1, 0, 60, 0, 0 ).IsValid = false )
		'' no leap seconds
		CU_ASSERT( DateTime( 2025, 1, 1, 0, 0, 60, 0 ).IsValid = false )

		'' the positive controls for the century rules
		CU_ASSERT( DateTime( 2024, 2, 29 ).IsValid )
		CU_ASSERT( DateTime( 2000, 2, 29 ).IsValid )
	END_TEST

	'' RFC-0001 section 3 rules 3 and 4.
	TEST( invalid_semantics_ )
		dim as DateTime bad = DateTime.Invalid
		dim as DateTime ok = DateTime( 2025, 3, 4 )

		CU_ASSERT( bad.IsValid = false )
		CU_ASSERT( bad.AddDays( 1 ).IsValid = false )
		CU_ASSERT( bad.AddTicks( 1 ).IsValid = false )
		CU_ASSERT( bad.GetDate( ).IsValid = false )
		CU_ASSERT( bad.GetTimeOfDay( ).IsValid = false )
		CU_ASSERT( bad.ToInstant( ).IsValid = false )
		CU_ASSERT( bad.WithOffset( 0 ).IsValid = false )
		CU_ASSERT( ( bad - ok ).IsValid = false )

		'' Invalid = Invalid is FALSE, deliberately
		CU_ASSERT( ( bad = bad ) = false )
		CU_ASSERT( ( bad <> ok ) = false )
		CU_ASSERT( ( bad < ok ) = false )
		CU_ASSERT( ( bad >= ok ) = false )
		CU_ASSERT( bad.CompareTo( ok ) = -2 )
	END_TEST

	'' Arithmetic never wraps.  RFC-0001 section 3 rule 2.
	TEST( arithmetic_overflow_ )
		CU_ASSERT( DateTime.MaxValue.AddTicks( 1 ).IsValid = false )
		CU_ASSERT( DateTime.MinValue.AddTicks( -1 ).IsValid = false )
		CU_ASSERT( DateTime.MaxValue.AddDays( 1 ).IsValid = false )
		CU_ASSERT( DateTime.MinValue.AddDays( -1 ).IsValid = false )
		CU_ASSERT( DateTime.MaxValue.AddMilliseconds( 1 ).IsValid = false )
		CU_ASSERT( DateTime.MaxValue.AddDays( 1e18 ).IsValid = false )

		'' the boundary itself is fine
		CU_ASSERT( DateTime.MaxValue.AddTicks( 0 ).IsValid )
		CU_ASSERT( DateTime.MinValue.AddTicks( 0 ).IsValid )
	END_TEST

	TEST( exact_arithmetic_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 )

		'' immutable: the receiver is untouched
		dim as DateTime e = d.AddDays( 3 )
		CU_ASSERT( d.Day = 4 )
		CU_ASSERT( e.Day = 7 )

		CU_ASSERT( d.AddTicks( DT_TICKS_PER_DAY ).Day = 5 )
		CU_ASSERT( d.AddHours( 24 ).Day = 5 )
		CU_ASSERT( d.AddMinutes( 60 ).Hour = 15 )
		CU_ASSERT( d.AddSeconds( 60 ).Minute = 31 )
		CU_ASSERT( d.AddMilliseconds( 1000 ).Second = 6 )

		'' AddDays( 1 ) is exactly 86400 seconds
		CU_ASSERT( d.AddDays( 1 ).Ticks - d.Ticks = DT_TICKS_PER_DAY )

		'' month and year rollover falls out of tick arithmetic
		CU_ASSERT( DateTime( 2025, 1, 31 ).AddDays( 1 ).Month = 2 )
		CU_ASSERT( DateTime( 2024, 2, 28 ).AddDays( 1 ).Day = 29 )
		CU_ASSERT( DateTime( 2025, 2, 28 ).AddDays( 1 ).Month = 3 )
		CU_ASSERT( DateTime( 2025, 12, 31 ).AddDays( 1 ).Year = 2026 )

		'' round trip through a TimeSpan
		dim as TimeSpan s = TimeSpan( 2, 3, 4, 5, 6 )
		CU_ASSERT( ( ( d + s ) - s ).Ticks = d.Ticks )
		CU_ASSERT( ( d.Add( s ).Subtract( s ) ).Ticks = d.Ticks )

		'' b - a, added back to a, gives b
		dim as DateTime b = DateTime( 2030, 7, 19, 1, 2, 3, 4 )
		CU_ASSERT( ( d + ( b - d ) ).Ticks = b.Ticks )
	END_TEST

	'' RFC-0001 section 2.1: unspecified is NOT the same state as UTC.
	TEST( offset_states_ )
		dim as DateTime naive = DateTime( 2025, 3, 4, 12, 0, 0, 0 )
		CU_ASSERT( naive.HasOffset = false )
		CU_ASSERT( naive.OffsetMinutes = DT_OFFSET_UNSPECIFIED )
		CU_ASSERT( naive.IsUtc = false )

		dim as DateTime utc = naive.WithOffset( 0 )
		CU_ASSERT( utc.IsUtc )
		CU_ASSERT( utc.HasOffset )

		dim as DateTime ist = naive.WithOffset( 330 )
		CU_ASSERT( ist.HasOffset )
		CU_ASSERT( ist.IsUtc = false )
		CU_ASSERT( ist.OffsetMinutes = 330 )

		'' a naive value cannot be placed on the UTC timeline
		CU_ASSERT( naive.ToInstant( ).IsValid = false )
		'' but AssumeUtc says so explicitly, and works
		CU_ASSERT( naive.AssumeUtc( ).IsValid )
		CU_ASSERT( naive.AssumeUtc( ).Ticks = naive.Ticks )

		'' offsets outside +/-18:00 are rejected
		CU_ASSERT( naive.WithOffset( 1081 ).IsValid = false )
		CU_ASSERT( naive.WithOffset( -1081 ).IsValid = false )
		CU_ASSERT( naive.WithOffset( 1080 ).IsValid )
	END_TEST

	'' WithOffset REINTERPRETS, ToOffset CONVERTS.  Asserted as a pair, which is
	'' the only way to catch them being implemented identically.
	TEST( with_offset_vs_to_offset_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 12, 0, 0, 0 ).WithOffset( 0 )

		dim as DateTime w = d.WithOffset( 60 )
		CU_ASSERT( w.Ticks = d.Ticks )                      '' wall reading kept
		CU_ASSERT( w.Hour = 12 )
		CU_ASSERT( w.ToInstant( ).Ticks <> d.ToInstant( ).Ticks )   '' instant moved

		dim as DateTime c = d.ToOffset( 60 )
		CU_ASSERT( c.Ticks <> d.Ticks )                     '' wall reading moved
		CU_ASSERT( c.Hour = 13 )
		CU_ASSERT( c.ToInstant( ).Ticks = d.ToInstant( ).Ticks )    '' instant kept

		'' ToOffset on a naive value has nothing to convert from
		CU_ASSERT( DateTime( 2025, 3, 4 ).ToOffset( 60 ).IsValid = false )
	END_TEST

	'' RFC-0004 section 1: offset-bearing values compare as instants; naive
	'' values compare as civil readings; mixing the two is not comparable.
	TEST( mixed_offset_comparison_ )
		dim as DateTime a = DateTime( 2025, 3, 4, 12, 0, 0, 0 ).WithOffset( 0 )
		dim as DateTime b = DateTime( 2025, 3, 4, 13, 0, 0, 0 ).WithOffset( 60 )
		'' same instant, different wall readings
		CU_ASSERT( a = b )
		CU_ASSERT( ( a - b ).Ticks = 0 )

		dim as DateTime n1 = DateTime( 2025, 3, 4, 12, 0, 0, 0 )
		dim as DateTime n2 = DateTime( 2025, 3, 4, 13, 0, 0, 0 )
		CU_ASSERT( n1 < n2 )
		CU_ASSERT( ( n2 - n1 ).TotalHours = 1 )

		'' one specified, one not: no defensible answer
		CU_ASSERT( ( a = n1 ) = false )
		CU_ASSERT( ( a < n1 ) = false )
		CU_ASSERT( ( a > n1 ) = false )
		CU_ASSERT( a.CompareTo( n1 ) = -2 )
		CU_ASSERT( ( a - n1 ).IsValid = false )
	END_TEST

	TEST( instant_ )
		dim as Instant i = Instant.FromTicks( 1000 )
		CU_ASSERT( i.IsValid )
		CU_ASSERT( i.Ticks = 1000 )
		CU_ASSERT( Instant.MinValue.Ticks = DT_MIN_TICKS )
		CU_ASSERT( Instant.MaxValue.Ticks = DT_MAX_TICKS )
		CU_ASSERT( Instant.Invalid.IsValid = false )
		CU_ASSERT( Instant.FromTicks( DT_MAX_TICKS + 1 ).IsValid = false )
		CU_ASSERT( Instant.FromTicks( -1 ).IsValid = false )

		dim as TimeSpan h = TimeSpan.FromHours( 1 )
		CU_ASSERT( ( i + h ).Ticks = 1000 + DT_TICKS_PER_HOUR )
		CU_ASSERT( ( ( i + h ) - h ).Ticks = i.Ticks )
		CU_ASSERT( ( ( i + h ) - i ).Ticks = DT_TICKS_PER_HOUR )
		CU_ASSERT( Instant.MaxValue.Add( h ).IsValid = false )
		CU_ASSERT( Instant.MinValue.Subtract( h ).IsValid = false )

		CU_ASSERT( i < i + h )
		CU_ASSERT( i = Instant.FromTicks( 1000 ) )
		CU_ASSERT( ( Instant.Invalid = Instant.Invalid ) = false )

		'' round trip Instant -> DateTime -> Instant, at several offsets
		dim as short offs( 0 to 4 ) = { 0, 60, -300, 330, 1080 }
		for k as integer = 0 to 4
			dim as Instant src = Instant.FromTicks( 638000000000000000ll )
			dim as DateTime dt = DateTime.FromInstant( src, offs( k ) )
			CU_ASSERT( dt.IsValid )
			CU_ASSERT( dt.OffsetMinutes = offs( k ) )
			CU_ASSERT( dt.ToInstant( ).Ticks = src.Ticks )
		next

		'' FromInstant needs a real offset, not "unspecified"
		CU_ASSERT( DateTime.FromInstant( i, DT_OFFSET_UNSPECIFIED ).IsValid = false )
	END_TEST

	TEST( localdate_ )
		dim as LocalDate d = LocalDate( 2025, 3, 4 )
		CU_ASSERT( d.IsValid )
		CU_ASSERT( d.Year = 2025 )
		CU_ASSERT( d.Month = 3 )
		CU_ASSERT( d.Day = 4 )
		CU_ASSERT( d.DayOfWeek = DT_TUESDAY )
		CU_ASSERT( d.DayOfYear = 63 )

		CU_ASSERT( LocalDate.MinValue.DayNumber = DT_MIN_DAYS )
		CU_ASSERT( LocalDate.MaxValue.DayNumber = DT_MAX_DAYS )
		CU_ASSERT( LocalDate.MinValue.Year = 1 )
		CU_ASSERT( LocalDate.MaxValue.Year = 9999 )
		CU_ASSERT( LocalDate( 2025, 2, 30 ).IsValid = false )
		CU_ASSERT( LocalDate.Invalid.IsValid = false )

		CU_ASSERT( d.AddDays( 1 ).Day = 5 )
		CU_ASSERT( d.AddDays( -1 ).Day = 3 )
		CU_ASSERT( ( LocalDate( 2025, 3, 7 ) - d ) = 3 )
		CU_ASSERT( d < LocalDate( 2025, 3, 5 ) )
		CU_ASSERT( d = LocalDate( 2025, 3, 4 ) )

		'' never wraps at the ends
		CU_ASSERT( LocalDate.MaxValue.AddDays( 1 ).IsValid = false )
		CU_ASSERT( LocalDate.MinValue.AddDays( -1 ).IsValid = false )
		CU_ASSERT( LocalDate.MaxValue.AddDays( 2147483647 ).IsValid = false )

		CU_ASSERT( ( LocalDate.Invalid = LocalDate.Invalid ) = false )
	END_TEST

	TEST( localtime_ )
		dim as LocalTime t = LocalTime( 14, 30, 5, 123 )
		CU_ASSERT( t.IsValid )
		CU_ASSERT( t.Hour = 14 )
		CU_ASSERT( t.Minute = 30 )
		CU_ASSERT( t.Second = 5 )
		CU_ASSERT( t.Millisecond = 123 )

		CU_ASSERT( LocalTime.Midnight.Ticks = 0 )
		CU_ASSERT( LocalTime.Noon.Hour = 12 )
		CU_ASSERT( LocalTime.MaxValue.Ticks = DT_TICKS_PER_DAY - 1 )
		CU_ASSERT( LocalTime.MaxValue.Hour = 23 )
		CU_ASSERT( LocalTime.Invalid.IsValid = false )

		CU_ASSERT( LocalTime( 24, 0, 0, 0 ).IsValid = false )
		CU_ASSERT( LocalTime( 0, 60, 0, 0 ).IsValid = false )
		CU_ASSERT( LocalTime( 0, 0, 60, 0 ).IsValid = false )
		CU_ASSERT( LocalTime.FromTicks( DT_TICKS_PER_DAY ).IsValid = false )
		CU_ASSERT( LocalTime.FromTicks( -1 ).IsValid = false )

		CU_ASSERT( ( LocalTime( 13, 0, 0, 0 ) - LocalTime( 12, 0, 0, 0 ) ).TotalHours = 1 )
		CU_ASSERT( LocalTime( 12, 0, 0, 0 ) < LocalTime( 13, 0, 0, 0 ) )
		CU_ASSERT( ( LocalTime.Invalid = LocalTime.Invalid ) = false )
	END_TEST

	'' Decomposition and recomposition must be lossless.
	TEST( date_time_decomposition_ )
		dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 123 )
		dim as LocalDate ld = d.GetDate( )
		dim as LocalTime lt = d.GetTimeOfDay( )

		CU_ASSERT( ld.Year = 2025 )
		CU_ASSERT( ld.Month = 3 )
		CU_ASSERT( ld.Day = 4 )
		CU_ASSERT( lt.Hour = 14 )
		CU_ASSERT( lt.Minute = 30 )

		CU_ASSERT( DateTime.FromDateTime( ld, lt ).Ticks = d.Ticks )
		CU_ASSERT( DateTime.FromDate( ld ).TickOfDay = 0 )
		CU_ASSERT( DateTime.FromDate( ld ).Day = 4 )

		CU_ASSERT( DateTime.FromDate( LocalDate.Invalid ).IsValid = false )
		CU_ASSERT( DateTime.FromDateTime( ld, LocalTime.Invalid ).IsValid = false )
	END_TEST

	'' A tick-level sweep: decompose and recompose across the whole range.
	TEST( roundtrip_sweep_ )
		dim as ulongint seed = 20250304ull

		for i as integer = 1 to 20000
			seed = ( seed * 6364136223846793005ull + 1442695040888963407ull )
			dim as longint t = clngint( seed mod culngint( DT_MAX_TICKS ) )

			dim as DateTime d = DateTime.FromTicks( t, DT_OFFSET_UNSPECIFIED )
			CU_ASSERT( d.IsValid )

			'' rebuild from the components alone
			dim as DateTime r = DateTime( d.Year, d.Month, d.Day, _
			                              d.Hour, d.Minute, d.Second, 0 )
			CU_ASSERT( r.IsValid )
			dim as longint sub_ = t mod DT_TICKS_PER_SECOND
			CU_ASSERT( r.Ticks + sub_ = t )

			'' and via the two half-types
			CU_ASSERT( DateTime.FromDateTime( d.GetDate( ), d.GetTimeOfDay( ) ).Ticks = t )
		next
	END_TEST

END_SUITE
