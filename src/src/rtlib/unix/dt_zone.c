/* chrono: timezone offsets and locale formatting, Unix backend.
**
** docs/datetime/RFC-0007-zones-locale-interop.md.
**
** localtime_r reads TZ / /etc/localtime, which is where glibc consults the
** system tz database.  That buys historical correctness for free, without this
** library shipping or maintaining a copy of the tzdb.
*/

#include "../fb.h"

#include <time.h>
#include <string.h>
#ifndef DISABLE_LANGINFO
#include <langinfo.h>
#endif

#define DT_ZONE_STYLE_SHORT  0
#define DT_ZONE_STYLE_LONG   1
#define DT_ZONE_STYLE_FULL   2

static time_t fb_hDtTicksToTimeT( long long utcTicks )
{
    return (time_t)( ( utcTicks - FB_DT_TICKS_TO_UNIX_EPOCH )
                     / FB_DT_TICKS_PER_SECOND );
}

/* Offset in minutes east of UTC AT THE GIVEN INSTANT, not "right now". */
/*:::::*/
FBCALL int fb_DtZoneOffsetAt( long long utcTicks )
{
    time_t t;
    struct tm tmv;

    if( !fb_DtIsValidTicks( utcTicks ) )
        return 0;
    t = fb_hDtTicksToTimeT( utcTicks );

    /* localtime_r, never localtime: this must be thread-safe. */
    if( localtime_r( &t, &tmv ) == NULL )
        return 0;

#if defined( __USE_BSD ) || defined( __USE_MISC ) || defined( __GLIBC__ ) || defined( __APPLE__ )
    return (int)( tmv.tm_gmtoff / 60 );
#else
    {
        struct tm gmv;
        time_t lt, gt;
        if( gmtime_r( &t, &gmv ) == NULL )
            return 0;
        tmv.tm_isdst = 0;
        gmv.tm_isdst = 0;
        lt = mktime( &tmv );
        gt = mktime( &gmv );
        return (int)( ( lt - gt ) / 60 );
    }
#endif
}

/*:::::*/
FBCALL int fb_DtZoneIsDst( long long utcTicks )
{
    time_t t;
    struct tm tmv;

    if( !fb_DtIsValidTicks( utcTicks ) )
        return 0;
    t = fb_hDtTicksToTimeT( utcTicks );
    if( localtime_r( &t, &tmv ) == NULL )
        return 0;
    return ( tmv.tm_isdst > 0 ) ? 1 : 0;
}

/*:::::*/
FBCALL int fb_DtZoneSupportsDst( void )
{
    /* Compare midwinter and midsummer of the current year: if the offset
    ** differs at all, the zone observes DST.  Cheaper and more portable than
    ** poking at the tzdb, and it does not care which hemisphere we are in. */
    time_t now = time( NULL );
    struct tm tmv;
    int janOff, julOff;
    long long jan, jul;
    int year;

    if( localtime_r( &now, &tmv ) == NULL )
        return 0;
    year = tmv.tm_year + 1900;
    if( year < FB_DT_MIN_YEAR || year > FB_DT_MAX_YEAR )
        return 0;

    if( fb_DtFromCivil( year, 1, 15, 12, 0, 0, 0, &jan ) )
        return 0;
    if( fb_DtFromCivil( year, 7, 15, 12, 0, 0, 0, &jul ) )
        return 0;

    janOff = fb_DtZoneOffsetAt( jan );
    julOff = fb_DtZoneOffsetAt( jul );
    return ( janOff != julOff ) ? 1 : 0;
}

static int fb_hDtCopyStr( const char *s, char *buf, int buflen )
{
    int n = 0;
    if( buf == NULL || buflen < 2 )
        return 0;
    if( s == NULL ) {
        buf[0] = 0;
        return 0;
    }
    while( s[n] && n < buflen - 1 ) {
        buf[n] = s[n];
        n++;
    }
    buf[n] = 0;
    return n;
}

/*:::::*/
FBCALL int fb_DtZoneStandardName( char *buf, int buflen )
{
    tzset( );
    return fb_hDtCopyStr( tzname[0], buf, buflen );
}

/*:::::*/
FBCALL int fb_DtZoneDaylightName( char *buf, int buflen )
{
    tzset( );
    return fb_hDtCopyStr( tzname[1], buf, buflen );
}

/* ---------------------------------------------------- locale formatting */

static void fb_hDtFillTm( long long ticks, struct tm *tmv )
{
    int y, mo, d, h, mi, s;
    long long sub;
    int days = (int)( ticks / FB_DT_TICKS_PER_DAY );

    fb_DtToCivil( ticks, &y, &mo, &d, &h, &mi, &s, &sub );
    memset( tmv, 0, sizeof( *tmv ) );
    tmv->tm_year = y - 1900;
    tmv->tm_mon = mo - 1;
    tmv->tm_mday = d;
    tmv->tm_hour = h;
    tmv->tm_min = mi;
    tmv->tm_sec = s;
    tmv->tm_wday = fb_DtDayOfWeek( days ) % 7;    /* tm_wday is Sunday = 0 */
    tmv->tm_yday = fb_DtDayOfYear( y, mo, d ) - 1;
    tmv->tm_isdst = -1;
}

/*:::::*/
FBCALL int fb_DtLocaleDateString( long long ticks, int style, char *buf, int buflen )
{
    struct tm tmv;
    const char *fmt;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( !fb_DtIsValidTicks( ticks ) ) return 0;
    fb_hDtFillTm( ticks, &tmv );

#ifndef DISABLE_LANGINFO
    fmt = ( style == DT_ZONE_STYLE_SHORT ) ? nl_langinfo( D_FMT ) : "%A %d %B %Y";
#else
    fmt = ( style == DT_ZONE_STYLE_SHORT ) ? "%x" : "%A %d %B %Y";
#endif
    if( fmt == NULL || *fmt == 0 )
        fmt = "%x";
    return (int)strftime( buf, (size_t)buflen, fmt, &tmv );
}

/*:::::*/
FBCALL int fb_DtLocaleTimeString( long long ticks, int style, char *buf, int buflen )
{
    struct tm tmv;
    const char *fmt;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( !fb_DtIsValidTicks( ticks ) ) return 0;
    fb_hDtFillTm( ticks, &tmv );

#ifndef DISABLE_LANGINFO
    fmt = nl_langinfo( T_FMT );
#else
    fmt = "%X";
#endif
    if( fmt == NULL || *fmt == 0 )
        fmt = "%X";
    if( style == DT_ZONE_STYLE_SHORT )
        fmt = "%H:%M";
    return (int)strftime( buf, (size_t)buflen, fmt, &tmv );
}

/*:::::*/
FBCALL int fb_DtLocaleMonthName( int mo, int abbreviated, char *buf, int buflen )
{
    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( mo < 1 || mo > 12 ) return 0;
#ifndef DISABLE_LANGINFO
    return fb_hDtCopyStr( nl_langinfo( ( abbreviated ? ABMON_1 : MON_1 ) + ( mo - 1 ) ),
                          buf, buflen );
#else
    {
        struct tm tmv;
        memset( &tmv, 0, sizeof( tmv ) );
        tmv.tm_mon = mo - 1;
        tmv.tm_mday = 1;
        return (int)strftime( buf, (size_t)buflen, abbreviated ? "%b" : "%B", &tmv );
    }
#endif
}

/*:::::*/
FBCALL int fb_DtLocaleWeekdayName( int dow, int abbreviated, char *buf, int buflen )
{
    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( dow < 1 || dow > 7 ) return 0;
    {
        /* this library is ISO 1=Monday; DAY_1 is Sunday */
        int sunFirst = ( dow % 7 );
#ifndef DISABLE_LANGINFO
        return fb_hDtCopyStr( nl_langinfo( ( abbreviated ? ABDAY_1 : DAY_1 ) + sunFirst ),
                              buf, buflen );
#else
        struct tm tmv;
        memset( &tmv, 0, sizeof( tmv ) );
        tmv.tm_wday = sunFirst;
        return (int)strftime( buf, (size_t)buflen, abbreviated ? "%a" : "%A", &tmv );
#endif
    }
}

/*:::::*/
FBCALL int fb_DtLocaleIsSupported( void )
{
    return 1;
}
