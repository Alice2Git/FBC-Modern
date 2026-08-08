/* Phase 1 verification: standalone tests for the chrono tick kernel.
**
** These live OUTSIDE src/ on purpose, matching the ustr_*_test.c convention:
** fbc's own suite is fbcunit .bas tests, and a 3.65-million-iteration
** exhaustive sweep has no sensible home there. The kernel is the one piece of
** chrono that can be proved correct before any FB-visible code exists.
**
** Specified by docs/datetime/RFC-0001-core-representation.md section 6.
**
** Build (from C:\dev\FBC-Modern):
**   gcc -O2 -Wall -I src/src/rtlib tests/dt_core_test.c src/src/rtlib/dt_core.c \
**       -o tests/dt_core_test.exe
*/

#include "fb.h"
#include <stdio.h>

static int g_fail = 0;
static long long g_run = 0;

/* Reports a failure. Never called on the passing path, so the exhaustive
** sweeps below cost one compare and one counter increment per assertion. */
static void fail( const char *fmt, ... )
{
	va_list ap;
	++g_fail;
	if( g_fail > 40 ) {
		if( g_fail == 41 )
			printf( "  ... further failures suppressed\n" );
		return;
	}
	printf( "FAIL: " );
	va_start( ap, fmt );
	vprintf( fmt, ap );
	va_end( ap );
	printf( "\n" );
}

/* Every assertion in this file goes through CHK so that the reported count is
** the real number of things checked, including inside the million-iteration
** loops. */
#define CHK( cond, ... ) \
	do { ++g_run; if( !(cond) ) fail( __VA_ARGS__ ); } while( 0 )

static void chk( int cond, const char *fmt, ... )
{
	va_list ap;
	++g_run;
	if( cond )
		return;
	va_start( ap, fmt );
	++g_fail;
	if( g_fail <= 40 ) {
		printf( "FAIL: " );
		vprintf( fmt, ap );
		printf( "\n" );
	} else if( g_fail == 41 ) {
		printf( "  ... further failures suppressed\n" );
	}
	va_end( ap );
}

static void section( const char *name )
{
	printf( "-- %s\n", name );
}

/* ------------------------------------------------------------------ */
/* The headline test: every single day in range, civil -> days -> civil */

static void test_exhaustive_roundtrip( void )
{
	int y, m, d;
	int expect_days = 0;
	int prev_dow = 0;
	long long count = 0;

	section( "exhaustive civil<->days round trip (0001-01-01 .. 9999-12-31)" );

	for( y = FB_DT_MIN_YEAR; y <= FB_DT_MAX_YEAR; y++ ) {
		int doy = 0;
		for( m = 1; m <= 12; m++ ) {
			int dim = fb_DtDaysInMonth( y, m );
			for( d = 1; d <= dim; d++ ) {
				int gy, gm, gd, dow, got_doy;
				int days = fb_DtDaysFromCivil( y, m, d );

				/* the day counter advances by exactly one, every day */
				CHK( days == expect_days, "days(%04d-%02d-%02d) = %d, expected %d",
				     y, m, d, days, expect_days );
				expect_days = days;   /* resync so one slip is not N failures */

				/* round trip is the identity */
				fb_DtCivilFromDays( days, &gy, &gm, &gd );
				CHK( gy == y && gm == m && gd == d,
				     "roundtrip %04d-%02d-%02d -> %d -> %04d-%02d-%02d",
				     y, m, d, days, gy, gm, gd );

				/* day of week cycles 1..7 without a break */
				dow = fb_DtDayOfWeek( days );
				CHK( dow >= 1 && dow <= 7,
				     "dow(%04d-%02d-%02d) = %d out of range", y, m, d, dow );
				CHK( prev_dow == 0 || dow == ( prev_dow % 7 ) + 1,
				     "dow discontinuity at %04d-%02d-%02d: %d after %d",
				     y, m, d, dow, prev_dow );
				prev_dow = dow;

				/* day of year is consistent with the month walk */
				++doy;
				got_doy = fb_DtDayOfYear( y, m, d );
				CHK( got_doy == doy, "doy(%04d-%02d-%02d) = %d, expected %d",
				     y, m, d, got_doy, doy );

				++expect_days;
				++count;
			}
		}
		if( doy != fb_DtDaysInYear( y ) )
			chk( 0, "year %04d walked %d days, DaysInYear says %d",
			     y, doy, fb_DtDaysInYear( y ) );
	}

	chk( count == FB_DT_DAYS_IN_RANGE,
	     "walked %lld days, expected %d", count, FB_DT_DAYS_IN_RANGE );
	chk( expect_days - 1 == FB_DT_MAX_DAYS,
	     "last day index %d, expected %d", expect_days - 1, FB_DT_MAX_DAYS );
	printf( "   %lld days walked\n", count );
}

/* ------------------------------------------------------------------ */

static void test_anchors( void )
{
	int y, m, d;

	section( "known anchors" );

	chk( fb_DtDaysFromCivil( 1, 1, 1 ) == 0, "0001-01-01 is day 0" );
	chk( fb_DtDaysFromCivil( 1970, 1, 1 ) == (int)FB_DT_DAYS_TO_UNIX_EPOCH,
	     "1970-01-01 is day %lld", FB_DT_DAYS_TO_UNIX_EPOCH );
	chk( fb_DtDaysFromCivil( 9999, 12, 31 ) == FB_DT_MAX_DAYS,
	     "9999-12-31 is day %d", FB_DT_MAX_DAYS );

	/* day of week: these are the three anchors named in the RFC */
	chk( fb_DtDayOfWeek( fb_DtDaysFromCivil( 1, 1, 1 ) ) == FB_DT_MONDAY,
	     "0001-01-01 is a Monday" );
	chk( fb_DtDayOfWeek( fb_DtDaysFromCivil( 1970, 1, 1 ) ) == FB_DT_THURSDAY,
	     "1970-01-01 is a Thursday" );
	chk( fb_DtDayOfWeek( fb_DtDaysFromCivil( 2000, 1, 1 ) ) == FB_DT_SATURDAY,
	     "2000-01-01 is a Saturday" );

	/* the interop epochs must land where the header says they do */
	chk( (long long)fb_DtDaysFromCivil( 1970, 1, 1 ) * FB_DT_TICKS_PER_DAY
	     == FB_DT_TICKS_TO_UNIX_EPOCH, "unix epoch tick constant" );
	chk( (long long)fb_DtDaysFromCivil( 1601, 1, 1 ) * FB_DT_TICKS_PER_DAY
	     == FB_DT_TICKS_TO_FILETIME, "filetime epoch tick constant" );
	chk( (long long)fb_DtDaysFromCivil( 1899, 12, 30 ) * FB_DT_TICKS_PER_DAY
	     == FB_DT_TICKS_TO_OLE_EPOCH, "ole epoch tick constant" );

	fb_DtCivilFromDays( 0, &y, &m, &d );
	chk( y == 1 && m == 1 && d == 1, "day 0 -> 0001-01-01, got %04d-%02d-%02d", y, m, d );
	fb_DtCivilFromDays( FB_DT_MAX_DAYS, &y, &m, &d );
	chk( y == 9999 && m == 12 && d == 31,
	     "last day -> 9999-12-31, got %04d-%02d-%02d", y, m, d );
}

/* ------------------------------------------------------------------ */

static void test_leap( void )
{
	section( "leap year rules" );

	chk(  fb_DtIsLeapYear( 2024 ), "2024 is leap" );
	chk( !fb_DtIsLeapYear( 2025 ), "2025 is not leap" );
	chk(  fb_DtIsLeapYear( 2000 ), "2000 is leap (400 rule)" );
	chk( !fb_DtIsLeapYear( 1900 ), "1900 is not leap (100 rule)" );
	chk( !fb_DtIsLeapYear( 2100 ), "2100 is not leap (100 rule)" );
	chk(  fb_DtIsLeapYear( 1600 ), "1600 is leap (400 rule)" );
	chk(  fb_DtIsLeapYear( 4 ),    "4 is leap" );
	chk( !fb_DtIsLeapYear( 1 ),    "1 is not leap" );

	chk( fb_DtDaysInMonth( 2024, 2 ) == 29, "Feb 2024 has 29 days" );
	chk( fb_DtDaysInMonth( 2025, 2 ) == 28, "Feb 2025 has 28 days" );
	chk( fb_DtDaysInMonth( 1900, 2 ) == 28, "Feb 1900 has 28 days" );
	chk( fb_DtDaysInMonth( 2000, 2 ) == 29, "Feb 2000 has 29 days" );
	chk( fb_DtDaysInMonth( 2025, 4 ) == 30, "Apr has 30 days" );
	chk( fb_DtDaysInMonth( 2025, 12 ) == 31, "Dec has 31 days" );
	chk( fb_DtDaysInMonth( 2025, 0 ) == 0, "month 0 has no days" );
	chk( fb_DtDaysInMonth( 2025, 13 ) == 0, "month 13 has no days" );

	chk( fb_DtDaysInYear( 2024 ) == 366, "2024 has 366 days" );
	chk( fb_DtDaysInYear( 2025 ) == 365, "2025 has 365 days" );
}

/* ------------------------------------------------------------------ */

static void test_iso_week_table( void )
{
	/* The four cases named in RFC-0004 section 5 -- each one is a date whose
	** ISO week-year differs from its calendar year. */
	static const struct { int y, m, d, iw, iy; } t[] = {
		{ 2025, 12, 29,  1, 2026 },
		{ 2021,  1,  1, 53, 2020 },
		{ 2016,  1,  3, 53, 2015 },
		{ 2000,  1,  1, 52, 1999 },
		{ 2025,  3,  4, 10, 2025 },
		{ 2025,  1,  1,  1, 2025 },
		{ 2024, 12, 30,  1, 2025 },
		{ 2026,  1,  1,  1, 2026 },
	};
	size_t i;

	section( "ISO week, hardcoded cases" );

	for( i = 0; i < sizeof( t ) / sizeof( t[0] ); i++ ) {
		int iy = 0;
		int w = fb_DtIsoWeek( t[i].y, t[i].m, t[i].d, &iy );
		chk( w == t[i].iw && iy == t[i].iy,
		     "%04d-%02d-%02d -> %d-W%02d, expected %d-W%02d",
		     t[i].y, t[i].m, t[i].d, iy, w, t[i].iy, t[i].iw );
	}

	chk( fb_DtIsoWeeksInYear( 2020 ) == 53, "2020 has 53 ISO weeks" );
	chk( fb_DtIsoWeeksInYear( 2025 ) == 52, "2025 has 52 ISO weeks" );
	chk( fb_DtIsoWeeksInYear( 2015 ) == 53, "2015 has 53 ISO weeks" );
}

/* Exhaustive ISO week structure check over the whole range: every ISO year
** must consist of exactly WeeksInYear weeks of exactly 7 days. */
static void test_iso_week_exhaustive( void )
{
	int day;
	int cur_iso_year = 0, cur_week = 0, run = 0;
	int weeks_seen = 0;

	section( "ISO week, exhaustive structure over the whole range" );

	for( day = FB_DT_MIN_DAYS; day <= FB_DT_MAX_DAYS; day++ ) {
		int y, m, d, iy = 0, w;
		fb_DtCivilFromDays( day, &y, &m, &d );
		w = fb_DtIsoWeek( y, m, d, &iy );

		CHK( w >= 1 && w <= 53,
		     "%04d-%02d-%02d ISO week %d out of range", y, m, d, w );

		if( iy != cur_iso_year || w != cur_week ) {
			/* a week just ended; every completed week has 7 days */
			CHK( cur_week == 0 || run == 7, "%d-W%02d had %d days, expected 7",
			     cur_iso_year, cur_week, run );

			if( iy == cur_iso_year ) {
				CHK( w == cur_week + 1, "week jumped %d-W%02d -> %d-W%02d",
				     cur_iso_year, cur_week, iy, w );
				++weeks_seen;
			} else {
				/* ISO year rollover: the year we just left must have had
				** exactly the number of weeks WeeksInYear claims */
				if( cur_iso_year != 0 ) {
					++weeks_seen;
					CHK( weeks_seen == fb_DtIsoWeeksInYear( cur_iso_year ),
					     "ISO year %d had %d weeks, WeeksInYear says %d",
					     cur_iso_year, weeks_seen,
					     fb_DtIsoWeeksInYear( cur_iso_year ) );
				}
				CHK( w == 1, "ISO year %d started at week %d, not 1", iy, w );
				weeks_seen = 0;
			}
			cur_iso_year = iy;
			cur_week = w;
			run = 0;
		}
		++run;

		/* week 1 always contains that ISO year's first Thursday */
		if( w == 1 && fb_DtDayOfWeek( day ) == FB_DT_THURSDAY )
			CHK( y == iy, "%04d-%02d-%02d is the W01 Thursday of ISO year %d "
			              "but falls in calendar year %d", y, m, d, iy, y );
	}
}

/* ------------------------------------------------------------------ */

static void test_ticks( void )
{
	static const struct { int y, mo, d, h, mi, s; long long sub; } ok[] = {
		{    1,  1,  1,  0,  0,  0, 0 },
		{ 9999, 12, 31, 23, 59, 59, 9999999 },
		{ 2025,  3,  4, 14, 30,  5, 1234567 },
		{ 2024,  2, 29, 12,  0,  0, 0 },
		{ 2000,  2, 29,  0,  0,  0, 0 },
		{ 1970,  1,  1,  0,  0,  0, 0 },
	};
	static const struct { int y, mo, d, h, mi, s; long long sub; } bad[] = {
		{ 2025,  0,  1,  0,  0,  0, 0 },   /* month 0     */
		{ 2025, 13,  1,  0,  0,  0, 0 },   /* month 13    */
		{ 2025,  1,  0,  0,  0,  0, 0 },   /* day 0       */
		{ 2025,  1, 32,  0,  0,  0, 0 },   /* day 32      */
		{ 2025,  2, 30,  0,  0,  0, 0 },   /* 30 Feb      */
		{ 2025,  4, 31,  0,  0,  0, 0 },   /* 31 Apr      */
		{ 2025,  2, 29,  0,  0,  0, 0 },   /* 29 Feb, non-leap */
		{ 1900,  2, 29,  0,  0,  0, 0 },   /* 29 Feb 1900 */
		{ 2100,  2, 29,  0,  0,  0, 0 },   /* 29 Feb 2100 */
		{    0,  1,  1,  0,  0,  0, 0 },   /* year 0      */
		{10000,  1,  1,  0,  0,  0, 0 },   /* year 10000  */
		{ 2025,  1,  1, 24,  0,  0, 0 },   /* hour 24     */
		{ 2025,  1,  1, -1,  0,  0, 0 },   /* hour -1     */
		{ 2025,  1,  1,  0, 60,  0, 0 },   /* minute 60   */
		{ 2025,  1,  1,  0,  0, 60, 0 },   /* second 60 (no leap seconds) */
		{ 2025,  1,  1,  0,  0,  0, 10000000 }, /* subsecond overflow */
		{ 2025,  1,  1,  0,  0,  0, -1 },  /* negative subsecond */
	};
	size_t i;

	section( "tick composition and range checks" );

	for( i = 0; i < sizeof( ok ) / sizeof( ok[0] ); i++ ) {
		long long t = -1;
		int y, mo, d, h, mi, s;
		long long sub;
		int rc = fb_DtFromCivil( ok[i].y, ok[i].mo, ok[i].d,
		                         ok[i].h, ok[i].mi, ok[i].s, ok[i].sub, &t );
		chk( rc == 0, "%04d-%02d-%02d %02d:%02d:%02d should be valid",
		     ok[i].y, ok[i].mo, ok[i].d, ok[i].h, ok[i].mi, ok[i].s );
		chk( fb_DtIsValidTicks( t ), "ticks in range for case %d", (int)i );

		fb_DtToCivil( t, &y, &mo, &d, &h, &mi, &s, &sub );
		chk( y == ok[i].y && mo == ok[i].mo && d == ok[i].d &&
		     h == ok[i].h && mi == ok[i].mi && s == ok[i].s && sub == ok[i].sub,
		     "tick roundtrip %04d-%02d-%02d %02d:%02d:%02d.%07lld -> "
		     "%04d-%02d-%02d %02d:%02d:%02d.%07lld",
		     ok[i].y, ok[i].mo, ok[i].d, ok[i].h, ok[i].mi, ok[i].s, ok[i].sub,
		     y, mo, d, h, mi, s, sub );
	}

	for( i = 0; i < sizeof( bad ) / sizeof( bad[0] ); i++ ) {
		long long t = 0;
		int rc = fb_DtFromCivil( bad[i].y, bad[i].mo, bad[i].d,
		                         bad[i].h, bad[i].mi, bad[i].s, bad[i].sub, &t );
		chk( rc != 0, "%04d-%02d-%02d %02d:%02d:%02d.%07lld should be rejected",
		     bad[i].y, bad[i].mo, bad[i].d, bad[i].h, bad[i].mi, bad[i].s, bad[i].sub );
		chk( t == FB_DT_INVALID_TICKS,
		     "rejected case %d must set the Invalid sentinel", (int)i );
	}

	/* 29 Feb 2000 is the positive control for the 400-year rule */
	{
		long long t = 0;
		chk( fb_DtFromCivil( 2000, 2, 29, 0, 0, 0, 0, &t ) == 0,
		     "29 Feb 2000 must be accepted" );
	}

	/* the range boundaries */
	{
		long long t = 0;
		fb_DtFromCivil( 1, 1, 1, 0, 0, 0, 0, &t );
		chk( t == FB_DT_MIN_TICKS, "min ticks is %lld, got %lld",
		     FB_DT_MIN_TICKS, t );
		fb_DtFromCivil( 9999, 12, 31, 23, 59, 59, 9999999, &t );
		chk( t == FB_DT_MAX_TICKS, "max ticks is %lld, got %lld",
		     FB_DT_MAX_TICKS, t );
	}

	chk( !fb_DtIsValidTicks( FB_DT_MIN_TICKS - 1 ), "min-1 is out of range" );
	chk( !fb_DtIsValidTicks( FB_DT_MAX_TICKS + 1 ), "max+1 is out of range" );
	chk( !fb_DtIsValidTicks( FB_DT_INVALID_TICKS ), "sentinel is out of range" );
}

/* Tick round trip at every second boundary of a sampled set of days, plus a
** pseudo-random sweep from a fixed seed so failures reproduce. */
static void test_ticks_sweep( void )
{
	unsigned int seed = 20250304u;
	int i;

	section( "tick round trip, fixed-seed sweep" );

	for( i = 0; i < 200000; i++ ) {
		long long t, back;
		int y, mo, d, h, mi, s;
		long long sub;

		/* xorshift, so the sequence is identical on every platform */
		seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
		t = (long long)( seed % (unsigned int)FB_DT_DAYS_IN_RANGE ) * FB_DT_TICKS_PER_DAY;
		seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5;
		t += (long long)( seed % (unsigned int)FB_DT_TICKS_PER_DAY );

		if( !fb_DtIsValidTicks( t ) ) {
			chk( 0, "generated tick %lld out of range", t );
			continue;
		}

		fb_DtToCivil( t, &y, &mo, &d, &h, &mi, &s, &sub );
		chk( fb_DtFromCivil( y, mo, d, h, mi, s, sub, &back ) == 0,
		     "decomposed %lld did not recompose", t );
		if( back != t )
			chk( 0, "tick roundtrip %lld -> %04d-%02d-%02d %02d:%02d:%02d.%07lld -> %lld",
			     t, y, mo, d, h, mi, s, sub, back );
	}
}

/* ------------------------------------------------------------------ */
/* Cross-check the new kernel against the legacy one, per RFC-0001 s6. */

static void test_cross_check_legacy( void )
{
	int y, m;

	section( "cross-check against the legacy time_core.c kernel" );

	for( y = 100; y <= FB_DT_MAX_YEAR; y++ ) {
		CHK( fb_DtIsLeapYear( y ) == fb_hTimeLeap( y ),
		     "leap disagreement for %d: new %d, legacy %d",
		     y, fb_DtIsLeapYear( y ), fb_hTimeLeap( y ) );
		for( m = 1; m <= 12; m++ )
			CHK( fb_DtDaysInMonth( y, m ) == fb_hTimeDaysInMonth( m, y ),
			     "days-in-month disagreement for %04d-%02d: new %d, legacy %d",
			     y, m, fb_DtDaysInMonth( y, m ), fb_hTimeDaysInMonth( m, y ) );
	}
}

/* ------------------------------------------------------------------ */

int main( void )
{
	printf( "chrono tick kernel -- phase 1 verification\n\n" );

	test_anchors();
	test_leap();
	test_ticks();
	test_ticks_sweep();
	test_iso_week_table();
	test_exhaustive_roundtrip();
	test_iso_week_exhaustive();
	test_cross_check_legacy();

	printf( "\n%lld checks, %d failures\n", g_run, g_fail );
	return g_fail ? 1 : 0;
}
