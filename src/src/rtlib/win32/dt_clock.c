/* chrono clocks: the Windows backend.  docs/datetime/RFC-0003-clocks.md */

#include "../fb.h"
#include <windows.h>

typedef void (WINAPI *FB_PRECISETIMEPROC)( LPFILETIME );

/* Resolved once.  GetSystemTimePreciseAsFileTime is Windows 8 / Server 2012;
** without it the wall clock granularity is ~15.6 ms, which is a real
** functional difference and is why fb_DtClockResolution( ) exists. */
static FB_PRECISETIMEPROC fb_hDtPreciseTime = NULL;
static int                fb_hDtPreciseTimeChecked = 0;

/*:::::*/
static FB_PRECISETIMEPROC fb_hDtGetPreciseTimeProc( void )
{
    if( !fb_hDtPreciseTimeChecked ) {
        HMODULE k32 = GetModuleHandle( "kernel32.dll" );
        if( k32 != NULL ) {
            /* via void*: casting FARPROC straight to a typed proc pointer
            ** trips -Wcast-function-type */
            fb_hDtPreciseTime = (FB_PRECISETIMEPROC)(void *)
                GetProcAddress( k32, "GetSystemTimePreciseAsFileTime" );
        }
        fb_hDtPreciseTimeChecked = 1;
    }
    return fb_hDtPreciseTime;
}

/*:::::*/
FBCALL long long fb_DtClockUtcNow( void )
{
    FILETIME ft;
    ULARGE_INTEGER u;
    long long ticks;
    FB_PRECISETIMEPROC precise = fb_hDtGetPreciseTimeProc( );

    if( precise != NULL )
        precise( &ft );
    else
        GetSystemTimeAsFileTime( &ft );

    u.LowPart = ft.dwLowDateTime;
    u.HighPart = ft.dwHighDateTime;

    /* FILETIME is ALREADY in this library's unit -- 100 ns ticks -- so the
    ** conversion is a single addition with no scaling and no rounding.  That
    ** is the payoff from RFC-0001's choice of epoch and tick size. */
    ticks = (long long)u.QuadPart + FB_DT_TICKS_TO_FILETIME;

    if( !fb_DtIsValidTicks( ticks ) )
        return FB_DT_INVALID_TICKS;
    return ticks;
}

/*:::::*/
FBCALL long long fb_DtClockResolution( void )
{
    if( fb_hDtGetPreciseTimeProc( ) != NULL )
        return 1;                       /* one tick, 100 ns */
    return 156250;                      /* ~15.6 ms, the classic tick period */
}

/*:::::*/
FBCALL int fb_DtClockLocalOffsetNow( void )
{
    TIME_ZONE_INFORMATION tzi;
    DWORD id = GetTimeZoneInformation( &tzi );
    LONG bias;

    if( id == TIME_ZONE_ID_INVALID )
        return 0;

    /* Bias is UTC = local + bias, i.e. the sign is inverted from what an
    ** "offset east of UTC" means. */
    bias = tzi.Bias;
    if( id == TIME_ZONE_ID_DAYLIGHT )
        bias += tzi.DaylightBias;
    else
        bias += tzi.StandardBias;

    return (int)-bias;
}

/*:::::*/
FBCALL long long fb_DtMonoTimestamp( void )
{
    LARGE_INTEGER c;
    if( !QueryPerformanceCounter( &c ) )
        return 0;
    return (long long)c.QuadPart;
}

/*:::::*/
FBCALL long long fb_DtMonoFrequency( void )
{
    static long long freq = 0;
    if( freq == 0 ) {
        LARGE_INTEGER f;
        if( QueryPerformanceFrequency( &f ) )
            freq = (long long)f.QuadPart;
        else
            freq = 1;
    }
    return freq;
}

/*:::::*/
FBCALL int fb_DtMonoIsHighRes( void )
{
    return 1;   /* QPC has been TSC-invariant-backed since Windows 7 */
}

/* FILETIME as returned by GetProcessTimes for user/kernel time is a DURATION
** in 100 ns units, not an absolute time -- so it is already in ticks. */
/*:::::*/
static long long fb_hDtFileTimeToTicks( const FILETIME *ft )
{
    ULARGE_INTEGER u;
    u.LowPart = ft->dwLowDateTime;
    u.HighPart = ft->dwHighDateTime;
    return (long long)u.QuadPart;
}

/*:::::*/
FBCALL int fb_DtCpuProcessTime( long long *user, long long *kernel )
{
    FILETIME cre, ex, krn, usr;

    if( !GetProcessTimes( GetCurrentProcess( ), &cre, &ex, &krn, &usr ) )
        return 1;

    if( user != NULL )   *user   = fb_hDtFileTimeToTicks( &usr );
    if( kernel != NULL ) *kernel = fb_hDtFileTimeToTicks( &krn );
    return 0;
}

/*:::::*/
FBCALL int fb_DtCpuThreadTime( long long *user, long long *kernel )
{
    FILETIME cre, ex, krn, usr;

    if( !GetThreadTimes( GetCurrentThread( ), &cre, &ex, &krn, &usr ) )
        return 1;

    if( user != NULL )   *user   = fb_hDtFileTimeToTicks( &usr );
    if( kernel != NULL ) *kernel = fb_hDtFileTimeToTicks( &krn );
    return 0;
}

/*:::::*/
FBCALL int fb_DtCpuIsSupported( void )
{
    return 1;
}
