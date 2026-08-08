/* chrono clocks: the Unix backend.  C:\dev\docs\datetime\RFC-0003-clocks.md */

#include "../fb.h"

#include <time.h>
#include <sys/time.h>
#include <sys/resource.h>

/*:::::*/
FBCALL long long fb_DtClockUtcNow( void )
{
    long long ticks;

#if defined( CLOCK_REALTIME )
    struct timespec ts;
    if( clock_gettime( CLOCK_REALTIME, &ts ) == 0 ) {
        ticks = (long long)ts.tv_sec * FB_DT_TICKS_PER_SECOND
              + (long long)ts.tv_nsec / 100
              + FB_DT_TICKS_TO_UNIX_EPOCH;
        if( !fb_DtIsValidTicks( ticks ) )
            return FB_DT_INVALID_TICKS;
        return ticks;
    }
#endif
    {
        struct timeval tv;
        if( gettimeofday( &tv, NULL ) != 0 )
            return FB_DT_INVALID_TICKS;
        ticks = (long long)tv.tv_sec * FB_DT_TICKS_PER_SECOND
              + (long long)tv.tv_usec * FB_DT_TICKS_PER_MICROSECOND
              + FB_DT_TICKS_TO_UNIX_EPOCH;
    }

    if( !fb_DtIsValidTicks( ticks ) )
        return FB_DT_INVALID_TICKS;
    return ticks;
}

/*:::::*/
FBCALL long long fb_DtClockResolution( void )
{
#if defined( CLOCK_REALTIME )
    struct timespec res;
    if( clock_getres( CLOCK_REALTIME, &res ) == 0 ) {
        long long t = (long long)res.tv_sec * FB_DT_TICKS_PER_SECOND
                    + (long long)res.tv_nsec / 100;
        if( t > 0 )
            return t;
        return 1;
    }
#endif
    return FB_DT_TICKS_PER_MICROSECOND;    /* gettimeofday resolves to 1 us */
}

/*:::::*/
FBCALL int fb_DtClockLocalOffsetNow( void )
{
    time_t now = time( NULL );
    struct tm tmv;

    /* localtime_r, never localtime: this must be thread-safe.  glibc consults
    ** TZ / /etc/localtime here, which is where the system tz database gets
    ** read -- historical correctness for free, without this library shipping
    ** or maintaining a copy. */
    if( localtime_r( &now, &tmv ) == NULL )
        return 0;

#if defined( __USE_BSD ) || defined( __USE_MISC ) || defined( __GLIBC__ ) || defined( __APPLE__ )
    return (int)( tmv.tm_gmtoff / 60 );
#else
    {
        /* No tm_gmtoff: derive it by differencing local and UTC renderings. */
        struct tm gmv;
        time_t lt, gt;
        if( gmtime_r( &now, &gmv ) == NULL )
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
FBCALL long long fb_DtMonoTimestamp( void )
{
#if defined( CLOCK_MONOTONIC )
    struct timespec ts;
    /* CLOCK_MONOTONIC rather than _RAW: it is slewed but never stepped, which
    ** is what a stopwatch wants, and it is the one that is cheap via vDSO. */
    if( clock_gettime( CLOCK_MONOTONIC, &ts ) == 0 )
        return (long long)ts.tv_sec * 1000000000ll + (long long)ts.tv_nsec;
#endif
    {
        struct timeval tv;
        if( gettimeofday( &tv, NULL ) != 0 )
            return 0;
        return (long long)tv.tv_sec * 1000000000ll
             + (long long)tv.tv_usec * 1000ll;
    }
}

/*:::::*/
FBCALL long long fb_DtMonoFrequency( void )
{
    return 1000000000ll;        /* the counter above is in nanoseconds */
}

/*:::::*/
FBCALL int fb_DtMonoIsHighRes( void )
{
#if defined( CLOCK_MONOTONIC )
    return 1;
#else
    return 0;
#endif
}

/*:::::*/
FBCALL int fb_DtCpuProcessTime( long long *user, long long *kernel )
{
    /* getrusage rather than CLOCK_PROCESS_CPUTIME_ID, because only getrusage
    ** splits user from kernel.  The cost is microsecond rather than nanosecond
    ** resolution, which RFC-0003 section 4 records. */
    struct rusage ru;
    if( getrusage( RUSAGE_SELF, &ru ) != 0 )
        return 1;

    if( user != NULL )
        *user = (long long)ru.ru_utime.tv_sec * FB_DT_TICKS_PER_SECOND
              + (long long)ru.ru_utime.tv_usec * FB_DT_TICKS_PER_MICROSECOND;
    if( kernel != NULL )
        *kernel = (long long)ru.ru_stime.tv_sec * FB_DT_TICKS_PER_SECOND
                + (long long)ru.ru_stime.tv_usec * FB_DT_TICKS_PER_MICROSECOND;
    return 0;
}

/*:::::*/
FBCALL int fb_DtCpuThreadTime( long long *user, long long *kernel )
{
    /* Linux gives a COMBINED per-thread figure only; the user/kernel split is
    ** not available per thread.  Report the total in *user and -1 in *kernel,
    ** as RFC-0003 section 4 specifies, rather than inventing a split. */
#if defined( CLOCK_THREAD_CPUTIME_ID )
    struct timespec ts;
    if( clock_gettime( CLOCK_THREAD_CPUTIME_ID, &ts ) == 0 ) {
        if( user != NULL )
            *user = (long long)ts.tv_sec * FB_DT_TICKS_PER_SECOND
                  + (long long)ts.tv_nsec / 100;
        if( kernel != NULL )
            *kernel = -1;
        return 0;
    }
#endif
    return 1;
}

/*:::::*/
FBCALL int fb_DtCpuIsSupported( void )
{
    return 1;
}
