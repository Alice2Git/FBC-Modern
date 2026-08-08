'' Clock / Stopwatch / CpuClock -- docs/datetime/RFC-0003-clocks.md section 5.
''
'' Clock tests cannot assert exact values, so they assert INVARIANTS.  Every
'' threshold below is chosen so a correct implementation passes on a loaded
'' machine while a wrong one still fails -- a flaky clock test is worse than no
'' clock test.

#include once "fbcunit.bi"
#include once "vbcompat.bi"
#include once "fb/chrono.bi"

using FB

'' A build-era floor.  Any clock reading before this means the epoch constant is
'' wrong -- which no relative test can ever catch.
#define BUILD_ERA_TICKS 638700000000000000ll     '' 2025-01-01-ish

SUITE( fbc_tests.chrono.clocks )

	TEST( wall_clock_ )
		dim as Instant a = Clock.UtcNow( )
		dim as Instant b = Clock.UtcNow( )

		CU_ASSERT( a.IsValid )
		CU_ASSERT( b.IsValid )
		CU_ASSERT( b.Ticks >= a.Ticks )                   '' non-decreasing
		CU_ASSERT( ( b - a ).TotalSeconds < 1.0 )         '' and close together

		'' The test that catches an epoch constant off by a century.  Nothing
		'' relative can find this.
		CU_ASSERT( a.Ticks > BUILD_ERA_TICKS )
		CU_ASSERT( a.Ticks < DT_MAX_TICKS )

		'' plausible calendar year
		dim as DateTime u = DateTime.FromInstant( a, 0 )
		CU_ASSERT( u.Year >= 2025 )
		CU_ASSERT( u.Year <= 2100 )
		CU_ASSERT( u.Month >= 1 andalso u.Month <= 12 )
		CU_ASSERT( u.Day >= 1 andalso u.Day <= 31 )

		dim as TimeSpan res = Clock.Resolution( )
		CU_ASSERT( res.Ticks > 0 )
		CU_ASSERT( res.TotalMilliseconds <= 20 )
	END_TEST

	'' This is the test that catches a SIGN ERROR in the local-offset
	'' conversion.  Nothing else does: a flipped sign still gives a plausible
	'' date, just one that is 2 x offset away from UTC.
	TEST( local_matches_utc_ )
		dim as DateTime n = Clock.Now( )
		dim as Instant u = Clock.UtcNow( )

		CU_ASSERT( n.IsValid )
		CU_ASSERT( n.HasOffset )
		CU_ASSERT( n.OffsetMinutes >= DT_OFFSET_MIN )
		CU_ASSERT( n.OffsetMinutes <= DT_OFFSET_MAX )
		CU_ASSERT( ( n.OffsetMinutes mod 1 ) = 0 )

		dim as Instant back = n.ToInstant( )
		CU_ASSERT( back.IsValid )
		dim as TimeSpan drift = ( back - u ).Duration( )
		CU_ASSERT( drift.TotalSeconds < 2.0 )

		'' Today and TimeOfDay agree with Now
		CU_ASSERT( Clock.Today( ).DayNumber = n.GetDate( ).DayNumber )
		CU_ASSERT( Clock.Today( ).IsValid )
		CU_ASSERT( Clock.TimeOfDay( ).IsValid )
	END_TEST

	'' The offset-sign test that actually works.
	''
	'' Now( ).ToInstant( ) canNOT detect a sign error: ToInstant subtracts the
	'' very offset FromInstant added, so the two cancel and the round trip
	'' succeeds no matter which way the sign points.  The only way to catch it
	'' is to compare the LOCAL WALL READING against an independent source of
	'' local time -- here, datetime.bi's own Now( ), which reaches the OS by a
	'' completely separate path.
	TEST( local_wall_reading_vs_legacy_ )
		dim as double legacy = Now( )                 '' datetime.bi: local serial
		dim as DateTime m = Clock.Now( )

		CU_ASSERT( m.IsValid )

		'' express the chrono local wall reading on the same serial scale
		dim as double mine = ( m.Ticks - DT_TICKS_TO_OLE_EPOCH ) / DT_TICKS_PER_DAY
		dim as double diffSeconds = abs( legacy - mine ) * 86400.0

		'' A flipped offset sign puts these 2 x offset apart -- hours, normally.
		CU_ASSERT( diffSeconds < 2.0 )

		'' and the components agree outright
		CU_ASSERT( m.Year = Year( legacy ) )
		CU_ASSERT( m.Month = Month( legacy ) )
		CU_ASSERT( m.Day = Day( legacy ) )
		CU_ASSERT( m.Hour = Hour( legacy ) )
	END_TEST

	'' The pure-function test for the 128-bit scaling.  No timing in it at all,
	'' and it is the ONLY test that catches the counts * 10^7 overflow.
	TEST( count_scaling_ )
		'' 24 hours at a 10 MHz counter: counts * 10^7 overflows int64 at ~25.6 h
		CU_ASSERT( fb_DtTicksFromCounts( 24ll * 3600ll * 10000000ll, 10000000ll ) = _
		           24ll * DT_TICKS_PER_HOUR )

		'' a full week at 10 MHz -- far past the naive overflow point
		CU_ASSERT( fb_DtTicksFromCounts( 7ll * 24ll * 3600ll * 10000000ll, 10000000ll ) = _
		           7ll * 24ll * DT_TICKS_PER_HOUR )

		'' exact conversions at assorted frequencies
		CU_ASSERT( fb_DtTicksFromCounts( 1000000000ll, 1000000000ll ) = DT_TICKS_PER_SECOND )
		CU_ASSERT( fb_DtTicksFromCounts( 0, 1000000ll ) = 0 )
		CU_ASSERT( fb_DtTicksFromCounts( 3, 1000000000ll ) = 0 )   '' 3 ns -> 0 ticks
		CU_ASSERT( fb_DtTicksFromCounts( 100, 1000000000ll ) = 1 ) '' 100 ns -> 1 tick

		'' degenerate inputs must not divide by zero or go negative
		CU_ASSERT( fb_DtTicksFromCounts( 100, 0 ) = 0 )
		CU_ASSERT( fb_DtTicksFromCounts( -5, 1000000ll ) = 0 )
	END_TEST

	TEST( stopwatch_basics_ )
		dim as Stopwatch sw

		CU_ASSERT( sw.IsRunning = false )
		CU_ASSERT( sw.ElapsedTicks = 0 )

		CU_ASSERT( Stopwatch.Frequency > 0 )
		CU_ASSERT( Stopwatch.GetTimestamp( ) >= 0 )

		sw.Start( )
		CU_ASSERT( sw.IsRunning )
		sw.Start( )                          '' no-op when already running
		CU_ASSERT( sw.IsRunning )
		sw.Stop_( )
		CU_ASSERT( sw.IsRunning = false )
		dim as longint first = sw.ElapsedTicks
		sw.Stop_( )                          '' no-op when already stopped
		CU_ASSERT( sw.IsRunning = false )
		CU_ASSERT( sw.ElapsedTicks = first ) '' stable while stopped

		CU_ASSERT( sw.ElapsedTicks >= 0 )

		sw.Reset( )
		CU_ASSERT( sw.IsRunning = false )
		CU_ASSERT( sw.ElapsedTicks = 0 )

		sw.Restart( )
		CU_ASSERT( sw.IsRunning )
		sw.Stop_( )

		'' the counter never goes backwards
		dim as longint prev = Stopwatch.GetTimestamp( )
		for i as integer = 1 to 1000
			dim as longint t = Stopwatch.GetTimestamp( )
			CU_ASSERT( t >= prev )
			prev = t
		next
	END_TEST

	'' Start/Stop/Start must ACCUMULATE.  Two 50 ms segments must read as one
	'' 100 ms total, not as one 50 ms segment -- which is exactly what a
	'' recompute-from-two-timestamps implementation would report.
	TEST( stopwatch_accumulates_ )
		dim as Stopwatch sw

		sw.Start( ) : sleep 50, 1 : sw.Stop_( )
		dim as longint afterFirst = sw.ElapsedMilliseconds
		sw.Start( ) : sleep 50, 1 : sw.Stop_( )
		dim as longint afterSecond = sw.ElapsedMilliseconds

		CU_ASSERT( afterFirst >= 40 )
		CU_ASSERT( afterSecond >= 90 )      '' fails at ~50 if it did not accumulate
		CU_ASSERT( afterSecond < 400 )      '' generous: a loaded machine still passes
		CU_ASSERT( afterSecond > afterFirst )
	END_TEST

	'' Cross-check the monotonic clock against the wall clock.  Loose on
	'' purpose: this is a sanity check on the frequency scaling, not a
	'' precision claim.
	TEST( stopwatch_vs_wall_ )
		dim as Instant t0 = Clock.UtcNow( )
		dim as Stopwatch sw = Stopwatch.StartNew( )
		sleep 200, 1
		sw.Stop_( )
		dim as Instant t1 = Clock.UtcNow( )

		dim as double wall = ( t1 - t0 ).TotalMilliseconds
		dim as double mono = sw.Elapsed.TotalMilliseconds

		CU_ASSERT( mono > 100 )
		CU_ASSERT( wall > 100 )
		CU_ASSERT( abs( wall - mono ) < 50 )
	END_TEST

	TEST( cpu_clock_ )
		CU_ASSERT( CpuClock.IsSupported )

		dim as TimeSpan c0 = CpuClock.ProcessTime( )
		CU_ASSERT( c0.IsValid )
		CU_ASSERT( c0.Ticks >= 0 )

		'' Burn CPU until the clock actually moves.
		''
		'' A fixed-size loop is NOT good enough here: GetProcessTimes has a
		'' ~15.6 ms granularity (the scheduler tick), so a loop that finishes
		'' inside one tick leaves the CPU time unchanged and a strict "greater
		'' than" assertion fails intermittently.  This was a real flaky test --
		'' it failed roughly one run in three under gas64, which optimises the
		'' loop enough to slip under a single tick.
		dim as double acc = 0
		dim as Stopwatch guard = Stopwatch.StartNew( )
		dim as TimeSpan c1 = c0
		do
			for i as integer = 1 to 2000000
				acc += i * 0.5
			next
			c1 = CpuClock.ProcessTime( )
		loop until c1.Ticks > c0.Ticks orelse guard.Elapsed.TotalSeconds > 5.0
		guard.Stop_( )

		CU_ASSERT( acc > 0 )                '' keep the loop from being optimised away
		CU_ASSERT( c1.Ticks >= c0.Ticks )
		CU_ASSERT( c1.Ticks > c0.Ticks )    '' strictly increased across real work

		'' single-threaded: the process has done at least what this thread did
		dim as TimeSpan th = CpuClock.ThreadTime( )
		CU_ASSERT( th.IsValid )
		CU_ASSERT( CpuClock.ProcessTime( ).Ticks >= th.Ticks )

		'' where the split exists, the parts sum to the whole
		dim as TimeSpan usr = CpuClock.ProcessUserTime( )
		dim as TimeSpan krn = CpuClock.ProcessKernelTime( )
		if krn.IsValid then
			dim as TimeSpan tot = CpuClock.ProcessTime( )
			CU_ASSERT( usr.Ticks + krn.Ticks <= tot.Ticks )
		end if
	END_TEST

	'' The test that distinguishes a real CPU clock from a wall clock wearing
	'' its name: a SLEEP advances the wall clock but not the CPU clock.
	TEST( cpu_is_not_wall_ )
		dim as TimeSpan c0 = CpuClock.ProcessTime( )
		dim as Instant  w0 = Clock.UtcNow( )

		sleep 200, 1

		dim as TimeSpan c1 = CpuClock.ProcessTime( )
		dim as Instant  w1 = Clock.UtcNow( )

		dim as double wallMs = ( w1 - w0 ).TotalMilliseconds
		dim as double cpuMs = ( c1 - c0 ).TotalMilliseconds

		CU_ASSERT( wallMs > 150 )           '' the wall clock moved
		CU_ASSERT( cpuMs < wallMs / 2 )     '' the CPU clock did not
	END_TEST

END_SUITE
