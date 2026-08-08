'' TimeSpan -- docs/datetime/RFC-0002-timespan.md section 6.

#include once "fbcunit.bi"
#include once "fb/chrono.bi"

using FB

SUITE( fbc_tests.chrono.spans )

	TEST( construction_ )
		CU_ASSERT( TimeSpan( ).Ticks = 0 )
		CU_ASSERT( TimeSpan( 123ll ).Ticks = 123 )
		CU_ASSERT( TimeSpan( 1, 2, 3 ).Ticks = _
		           1 * DT_TICKS_PER_HOUR + 2 * DT_TICKS_PER_MINUTE + 3 * DT_TICKS_PER_SECOND )
		CU_ASSERT( TimeSpan( 1, 2, 3, 4, 5 ).Ticks = _
		           1 * DT_TICKS_PER_DAY + 2 * DT_TICKS_PER_HOUR + _
		           3 * DT_TICKS_PER_MINUTE + 4 * DT_TICKS_PER_SECOND + _
		           5 * DT_TICKS_PER_MILLISECOND )

		CU_ASSERT( TimeSpan.Zero.Ticks = 0 )
		CU_ASSERT( TimeSpan.MaxValue.Ticks = 9223372036854775807ll )
		CU_ASSERT( TimeSpan.MinValue.Ticks = -9223372036854775807ll )
		CU_ASSERT( TimeSpan.Invalid.IsValid = false )
		CU_ASSERT( TimeSpan.MinValue.IsValid )
		CU_ASSERT( TimeSpan.MaxValue.IsValid )

		CU_ASSERT( TimeSpan.FromDays( 1 ).Ticks = DT_TICKS_PER_DAY )
		CU_ASSERT( TimeSpan.FromHours( 1 ).Ticks = DT_TICKS_PER_HOUR )
		CU_ASSERT( TimeSpan.FromMinutes( 1 ).Ticks = DT_TICKS_PER_MINUTE )
		CU_ASSERT( TimeSpan.FromSeconds( 1 ).Ticks = DT_TICKS_PER_SECOND )
		CU_ASSERT( TimeSpan.FromMilliseconds( 1 ).Ticks = DT_TICKS_PER_MILLISECOND )
		CU_ASSERT( TimeSpan.FromMicroseconds( 1 ).Ticks = DT_TICKS_PER_MICROSECOND )
		CU_ASSERT( TimeSpan.FromTicks( 42 ).Ticks = 42 )

		'' fractional, because From* take a double on purpose
		CU_ASSERT( TimeSpan.FromHours( 1.5 ).Ticks = 90 * DT_TICKS_PER_MINUTE )
		CU_ASSERT( TimeSpan.FromDays( 0.5 ).Ticks = 12 * DT_TICKS_PER_HOUR )
	END_TEST

	'' RFC-0002 section 3: the worked example, plus the reconstruction identity.
	TEST( totals_vs_components_ )
		dim as TimeSpan s = TimeSpan( 1, 2, 3, 0, 0 )   '' 1d 2h 3m

		CU_ASSERT( abs( s.TotalHours - 26.05 ) < 0.000001 )
		CU_ASSERT( s.Hours = 2 )
		CU_ASSERT( abs( s.TotalMinutes - 1563.0 ) < 0.000001 )
		CU_ASSERT( s.Minutes = 3 )
		CU_ASSERT( s.Days = 1 )
		CU_ASSERT( abs( s.TotalDays - ( 1.0 + 2.0/24.0 + 3.0/1440.0 ) ) < 0.000001 )

		'' the pieces must reconstruct the whole, for every sign
		dim as TimeSpan tbl( 0 to 8 ) = { _
			TimeSpan.Zero, _
			TimeSpan( 1, 2, 3, 4, 5 ), _
			TimeSpan( -1, -2, -3, -4, -5 ), _
			TimeSpan( 0, 0, 0, 0, 1 ), _
			TimeSpan( 0, 0, 0, 0, -1 ), _
			TimeSpan.FromTicks( 1 ), _
			TimeSpan.FromTicks( -1 ), _
			TimeSpan.MaxValue, _
			TimeSpan.MinValue }

		for i as integer = 0 to 8
			dim as TimeSpan v = tbl( i )
			dim as longint rebuilt = _
				clngint( v.Days ) * DT_TICKS_PER_DAY + _
				clngint( v.Hours ) * DT_TICKS_PER_HOUR + _
				clngint( v.Minutes ) * DT_TICKS_PER_MINUTE + _
				clngint( v.Seconds ) * DT_TICKS_PER_SECOND + _
				clngint( v.Milliseconds ) * DT_TICKS_PER_MILLISECOND + _
				( v.Ticks mod DT_TICKS_PER_MILLISECOND )
			CU_ASSERT( rebuilt = v.Ticks )
		next
	END_TEST

	'' Components of a negative span are ALL negative, matching C#.
	TEST( negative_components_ )
		dim as TimeSpan n = TimeSpan( 0, -1, -30, 0, 0 )
		CU_ASSERT( n.Hours = -1 )
		CU_ASSERT( n.Minutes = -30 )
		CU_ASSERT( n.IsNegative )
		CU_ASSERT( n.TotalMinutes < 0 )

		dim as TimeSpan h = TimeSpan.FromHours( -1.5 )
		CU_ASSERT( h.Hours = -1 )
		CU_ASSERT( h.Minutes = -30 )

		CU_ASSERT( TimeSpan.Zero.IsNegative = false )
		CU_ASSERT( TimeSpan.Zero.IsZero )
		CU_ASSERT( TimeSpan.Invalid.IsNegative = false )
	END_TEST

	'' Rounding is half away from zero, per RFC-0002 section 2.
	TEST( rounding_ )
		'' half a tick either way
		CU_ASSERT( TimeSpan.FromSeconds( 0.00000005 ).Ticks = 1 )
		CU_ASSERT( TimeSpan.FromSeconds( -0.00000005 ).Ticks = -1 )
		'' a third of a millisecond is 3333.33 ticks -> 3333
		CU_ASSERT( TimeSpan.FromMilliseconds( 1.0/3.0 ).Ticks = 3333 )
	END_TEST

	'' RFC-0002 section 4: overflow yields Invalid and NEVER wraps.
	TEST( overflow_ )
		dim as TimeSpan one = TimeSpan.FromTicks( 1 )

		CU_ASSERT( TimeSpan.MaxValue.Add( one ).IsValid = false )

		'' Proving "did not wrap" needs an input where the wrapped value and the
		'' sentinel DIFFER.  MaxValue + 1 is not that input: it wraps to exactly
		'' LLONG_MIN, which IS the sentinel, so the two are indistinguishable.
		'' MaxValue + 2 wraps to LLONG_MIN + 1 = MinValue, which is not.
		dim as TimeSpan over2 = TimeSpan.MaxValue.Add( TimeSpan.FromTicks( 2 ) )
		CU_ASSERT( over2.IsValid = false )
		CU_ASSERT( over2.Ticks <> TimeSpan.MinValue.Ticks )

		CU_ASSERT( TimeSpan.MinValue.Subtract( one ).IsValid = false )
		CU_ASSERT( TimeSpan.MaxValue.Multiply( 2 ).IsValid = false )
		CU_ASSERT( TimeSpan.FromTicks( 100 ).Divide( 0 ).IsValid = false )

		'' MinValue is LLONG_MIN + 1, so negating it IS representable
		CU_ASSERT( TimeSpan.MinValue.Negate( ).Ticks = TimeSpan.MaxValue.Ticks )
		CU_ASSERT( TimeSpan.MinValue.Duration( ).Ticks = TimeSpan.MaxValue.Ticks )

		'' non-finite input
		dim as double zero = 0.0
		dim as double nan_ = zero / zero
		CU_ASSERT( TimeSpan.FromHours( nan_ ).IsValid = false )
		CU_ASSERT( TimeSpan.FromDays( 1e30 ).IsValid = false )
		CU_ASSERT( TimeSpan.FromDays( -1e30 ).IsValid = false )
	END_TEST

	'' Invalid is absorbing, and comparisons against it are all false.
	TEST( invalid_semantics_ )
		dim as TimeSpan bad = TimeSpan.Invalid
		dim as TimeSpan ok = TimeSpan.FromHours( 1 )

		CU_ASSERT( bad.Add( ok ).IsValid = false )
		CU_ASSERT( ok.Add( bad ).IsValid = false )
		CU_ASSERT( bad.Subtract( ok ).IsValid = false )
		CU_ASSERT( bad.Negate( ).IsValid = false )
		CU_ASSERT( bad.Duration( ).IsValid = false )
		CU_ASSERT( bad.Multiply( 2 ).IsValid = false )

		'' every comparison with an Invalid operand is false -- including =
		CU_ASSERT( ( bad = bad ) = false )
		CU_ASSERT( ( bad = ok ) = false )
		CU_ASSERT( ( bad <> ok ) = false )
		CU_ASSERT( ( bad < ok ) = false )
		CU_ASSERT( ( bad > ok ) = false )
		CU_ASSERT( ( bad <= ok ) = false )
		CU_ASSERT( ( bad >= ok ) = false )
		CU_ASSERT( bad.CompareTo( ok ) = -2 )

		'' DivideBy zero and by invalid both give NaN (not equal to itself)
		dim as double r = ok.DivideBy( TimeSpan.Zero )
		CU_ASSERT( r <> r )
	END_TEST

	TEST( arithmetic_and_operators_ )
		dim as TimeSpan a = TimeSpan.FromHours( 3 )
		dim as TimeSpan b = TimeSpan.FromMinutes( 30 )

		CU_ASSERT( ( a + b ).Ticks = a.Add( b ).Ticks )
		CU_ASSERT( ( a - b ).Ticks = a.Subtract( b ).Ticks )
		CU_ASSERT( ( a + b ).TotalHours = 3.5 )
		CU_ASSERT( ( a - b ).TotalHours = 2.5 )
		CU_ASSERT( ( -a ).Ticks = -a.Ticks )
		CU_ASSERT( ( a * 2 ).TotalHours = 6 )
		CU_ASSERT( ( 2 * a ).TotalHours = 6 )
		CU_ASSERT( ( a / 2 ).TotalHours = 1.5 )
		CU_ASSERT( a.DivideBy( b ) = 6.0 )

		'' subtraction past zero is meaningful, not an error
		CU_ASSERT( ( b - a ).IsNegative )
		CU_ASSERT( ( b - a ).TotalHours = -2.5 )

		CU_ASSERT( a > b )
		CU_ASSERT( b < a )
		CU_ASSERT( a >= a )
		CU_ASSERT( a <= a )
		CU_ASSERT( a = TimeSpan.FromHours( 3 ) )
		CU_ASSERT( a <> b )
		CU_ASSERT( a.CompareTo( b ) = 1 )
		CU_ASSERT( b.CompareTo( a ) = -1 )
		CU_ASSERT( a.CompareTo( a ) = 0 )

		CU_ASSERT( TimeSpan.FromHours( -2 ).Duration( ).TotalHours = 2 )
		CU_ASSERT( TimeSpan.FromHours( 2 ).Duration( ).TotalHours = 2 )
	END_TEST

END_SUITE
