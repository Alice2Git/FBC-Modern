/* chrono kernel: civil calendar <-> tick conversion.
**
** Specified by C:\dev\docs\datetime\RFC-0001-core-representation.md.
**
** Pure. No OS calls, no allocation, no locale, no globals. Proleptic
** Gregorian throughout -- the Gregorian rules projected back past 1582, with
** no Julian calendar and no cutover, which is what ISO 8601 requires.
**
** The two conversion primitives use the closed-form days-from-civil
** algorithm: shift the year to start in March so the leap day lands last,
** then do arithmetic on the 146097-day 400-year cycle. No lookup table and
** no loop over years, which is what makes the exhaustive round-trip test
** cheap enough to run every build.
*/

#include "fb.h"

/* The algorithm's natural origin is 0000-03-01. Hinnant's published form
** returns days from 1970-01-01 via a -719468 shift; we want days from
** 0001-01-01, which is 719162 days earlier, so the two constants fold into
** a single -306. */
#define DT_ERA_SHIFT       306
#define DT_DAYS_PER_ERA    146097     /* 400 Gregorian years */

/*:::::*/
FBCALL int fb_DtIsLeapYear( int year )
{
    if( ( year % 400 ) == 0 )
        return 1;
    if( ( year % 100 ) == 0 )
        return 0;
    return ( ( year % 4 ) == 0 ) ? 1 : 0;
}

/*:::::*/
FBCALL int fb_DtDaysInMonth( int year, int month )
{
    static const int days[] =
    { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    if( month < 1 || month > 12 )
        return 0;
    if( month == 2 )
        return 28 + fb_DtIsLeapYear( year );
    return days[month - 1];
}

/*:::::*/
FBCALL int fb_DtDaysInYear( int year )
{
    return 365 + fb_DtIsLeapYear( year );
}

/*:::::*/
FBCALL int fb_DtDaysFromCivil( int year, int month, int day )
{
    int era, yoe, doy, doe;

    /* March-based year: the leap day becomes the last day, so the
    ** 4/100/400 rules need no special case below. */
    year -= ( month <= 2 );

    era = ( year >= 0 ? year : year - 399 ) / 400;
    yoe = year - era * 400;                                  /* 0 .. 399   */
    doy = ( 153 * ( month + ( month > 2 ? -3 : 9 ) ) + 2 ) / 5
          + day - 1;                                         /* 0 .. 365   */
    doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;              /* 0 .. 146096*/

    return era * DT_DAYS_PER_ERA + doe - DT_ERA_SHIFT;
}

/*:::::*/
FBCALL void fb_DtCivilFromDays( int days, int *year, int *month, int *day )
{
    int era, doe, yoe, doy, mp, y, m, d;

    days += DT_ERA_SHIFT;

    era = ( days >= 0 ? days : days - ( DT_DAYS_PER_ERA - 1 ) ) / DT_DAYS_PER_ERA;
    doe = days - era * DT_DAYS_PER_ERA;                      /* 0 .. 146096 */
    yoe = ( doe - doe / 1460 + doe / 36524 - doe / 146096 ) / 365;
    y   = yoe + era * 400;
    doy = doe - ( 365 * yoe + yoe / 4 - yoe / 100 );          /* 0 .. 365    */
    mp  = ( 5 * doy + 2 ) / 153;                              /* 0 .. 11     */
    d   = doy - ( 153 * mp + 2 ) / 5 + 1;                     /* 1 .. 31     */
    m   = mp + ( mp < 10 ? 3 : -9 );                          /* 1 .. 12     */
    y  += ( m <= 2 );

    if( year  != NULL ) *year  = y;
    if( month != NULL ) *month = m;
    if( day   != NULL ) *day   = d;
}

/*:::::*/
FBCALL int fb_DtDayOfWeek( int days )
{
    /* Day 0 is 0001-01-01, which is a Monday. */
    int r = days % 7;
    if( r < 0 )
        r += 7;
    return r + 1;
}

/*:::::*/
FBCALL int fb_DtDayOfYear( int year, int month, int day )
{
    return fb_DtDaysFromCivil( year, month, day )
         - fb_DtDaysFromCivil( year, 1, 1 ) + 1;
}

/* Weekday of 31 December of `year`, as 0..6. The standard ISO helper. */
/*:::::*/
static int fb_hDtIsoP( int year )
{
    return ( year + year / 4 - year / 100 + year / 400 ) % 7;
}

/*:::::*/
FBCALL int fb_DtIsoWeeksInYear( int year )
{
    return ( fb_hDtIsoP( year ) == 4 || fb_hDtIsoP( year - 1 ) == 3 ) ? 53 : 52;
}

/*:::::*/
FBCALL int fb_DtIsoWeek( int year, int month, int day, int *out_iso_year )
{
    int doy, dow, week, iso_year;

    doy  = fb_DtDayOfYear( year, month, day );
    dow  = fb_DtDayOfWeek( fb_DtDaysFromCivil( year, month, day ) );

    /* Week 1 is the week containing the first Thursday of the year. */
    week     = ( doy - dow + 10 ) / 7;
    iso_year = year;

    if( week < 1 ) {
        /* Belongs to the last week of the previous ISO year. */
        iso_year = year - 1;
        week     = fb_DtIsoWeeksInYear( iso_year );
    } else if( week > fb_DtIsoWeeksInYear( year ) ) {
        /* Belongs to week 1 of the next ISO year. */
        iso_year = year + 1;
        week     = 1;
    }

    if( out_iso_year != NULL )
        *out_iso_year = iso_year;

    return week;
}

/*:::::*/
FBCALL int fb_DtIsValidDate( int year, int month, int day )
{
    if( year < FB_DT_MIN_YEAR || year > FB_DT_MAX_YEAR )
        return 0;
    if( month < 1 || month > 12 )
        return 0;
    if( day < 1 || day > fb_DtDaysInMonth( year, month ) )
        return 0;
    return 1;
}

/*:::::*/
FBCALL int fb_DtIsValidTime( int hour, int minute, int second,
                      long long subsecond_ticks )
{
    if( hour < 0 || hour > 23 )
        return 0;
    if( minute < 0 || minute > 59 )
        return 0;
    /* No leap seconds: 60 is not a valid second. See C:\dev\docs\datetime\rationale.md */
    if( second < 0 || second > 59 )
        return 0;
    if( subsecond_ticks < 0 || subsecond_ticks >= FB_DT_TICKS_PER_SECOND )
        return 0;
    return 1;
}

/*:::::*/
FBCALL int fb_DtIsValidTicks( long long ticks )
{
    return ( ticks >= FB_DT_MIN_TICKS && ticks <= FB_DT_MAX_TICKS ) ? 1 : 0;
}

/*:::::*/
FBCALL int fb_DtFromCivil( int year, int month, int day,
                    int hour, int minute, int second,
                    long long subsecond_ticks,
                    long long *out_ticks )
{
    if( out_ticks != NULL )
        *out_ticks = FB_DT_INVALID_TICKS;

    if( !fb_DtIsValidDate( year, month, day ) )
        return 1;
    if( !fb_DtIsValidTime( hour, minute, second, subsecond_ticks ) )
        return 1;

    if( out_ticks != NULL ) {
        *out_ticks = (long long)fb_DtDaysFromCivil( year, month, day )
                        * FB_DT_TICKS_PER_DAY
                   + (long long)hour   * FB_DT_TICKS_PER_HOUR
                   + (long long)minute * FB_DT_TICKS_PER_MINUTE
                   + (long long)second * FB_DT_TICKS_PER_SECOND
                   + subsecond_ticks;
    }

    return 0;
}

/*:::::*/
FBCALL void fb_DtToCivil( long long ticks,
                   int *year, int *month, int *day,
                   int *hour, int *minute, int *second,
                   long long *subsecond_ticks )
{
    int days;
    long long tod;

    DBG_ASSERT( fb_DtIsValidTicks( ticks ) );

    days = (int)( ticks / FB_DT_TICKS_PER_DAY );
    tod  = ticks % FB_DT_TICKS_PER_DAY;
    if( tod < 0 ) {
        /* C truncates toward zero; the calendar needs floor. */
        tod += FB_DT_TICKS_PER_DAY;
        --days;
    }

    fb_DtCivilFromDays( days, year, month, day );

    if( hour   != NULL ) *hour   = (int)( tod / FB_DT_TICKS_PER_HOUR );
    if( minute != NULL ) *minute = (int)( tod / FB_DT_TICKS_PER_MINUTE % 60 );
    if( second != NULL ) *second = (int)( tod / FB_DT_TICKS_PER_SECOND % 60 );
    if( subsecond_ticks != NULL )
        *subsecond_ticks = tod % FB_DT_TICKS_PER_SECOND;
}

/*:::::*/
FBCALL long long fb_DtTicksFromCounts( long long counts, long long freq )
{
    if( freq <= 0 )
        return 0;
    if( counts < 0 )
        return 0;

    /* counts * 10^7 / freq.
    **
    ** The order matters and so does the width: at a 10 MHz QPC frequency,
    ** counts * 10^7 overflows a signed 64-bit integer after about 25.6 hours,
    ** which is well inside what a real program does.  Do the multiply in 128
    ** bits where the compiler has them. */
#if defined( __SIZEOF_INT128__ )
    {
        unsigned __int128 wide = (unsigned __int128)counts
                               * (unsigned __int128)FB_DT_TICKS_PER_SECOND;
        return (long long)( wide / (unsigned __int128)freq );
    }
#else
    {
        /* Portable fallback: split into whole seconds and remainder so that
        ** neither product can overflow.  Exact, not an approximation. */
        long long whole = counts / freq;
        long long rem   = counts % freq;
        return whole * FB_DT_TICKS_PER_SECOND
             + ( rem * FB_DT_TICKS_PER_SECOND ) / freq;
    }
#endif
}
