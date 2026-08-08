/* chrono: timezone offsets and locale formatting, Windows backend.
**
** C:\dev\docs\datetime\RFC-0007-zones-locale-interop.md.
**
** NOTE the file name exists ONLY under win32/ and unix/.  A per-OS .c that
** shares a base name with one in src/rtlib/ is silently dropped by the
** makefile's $(sort) -- see C:\dev\docs\datetime\README.md.
*/

/* GetDynamicTimeZoneInformation, GetTimeZoneInformationForYear, GetLocaleInfoEx,
** GetDateFormatEx / GetTimeFormatEx and LOCALE_NAME_USER_DEFAULT are all
** Vista-and-later, and mingw gates them behind _WIN32_WINNT.  The 64-bit
** headers default high enough and the 32-bit ones do NOT, so the 64-bit build
** compiles clean while the 32-bit build fails outright -- say it explicitly,
** and say it BEFORE any header is pulled in. */
#undef  _WIN32_WINNT
#define _WIN32_WINNT 0x0600
#undef  WINVER
#define WINVER 0x0600

#include "../fb.h"
#include <windows.h>

#define DT_ZONE_STYLE_SHORT  0
#define DT_ZONE_STYLE_LONG   1
#define DT_ZONE_STYLE_FULL   2

/* UTF-16 -> UTF-8 at the boundary; everything above this layer is UTF-8. */
static int fb_hDtW2U( const WCHAR *w, char *buf, int buflen )
{
    int n;
    if( w == NULL || buf == NULL || buflen < 2 )
        return 0;
    n = WideCharToMultiByte( CP_UTF8, 0, w, -1, buf, buflen - 1, NULL, NULL );
    if( n <= 0 ) {
        buf[0] = 0;
        return 0;
    }
    /* n includes the terminating NUL */
    buf[n - 1] = 0;
    return n - 1;
}

/* Fill a TIME_ZONE_INFORMATION appropriate to the YEAR of the given UTC time.
**
** GetTimeZoneInformationForYear, not GetTimeZoneInformation: only the dynamic
** form knows historical rules.  The static one applies today's DST rule to
** every year, which silently misdates anything from before a rule change.
** AfxNova's AfxTimeZone* family uses the static form and inherits that bug;
** this is a deliberate divergence from the requirements source. */
/* GetTimeZoneInformationForYear is Windows 7, and mingw only declares it at
** _WIN32_WINNT >= 0x0601.  Resolve it at run time rather than raising the whole
** binary's minimum OS with a static import -- the same approach dt_clock.c
** takes for the Windows 8 precise-time API.  When it is absent the static
** fallback below still gives a correct answer for the CURRENT year, which is
** what the old AfxNova behaviour was. */
typedef WINBOOL (WINAPI *FB_TZFORYEARPROC)( USHORT, PDYNAMIC_TIME_ZONE_INFORMATION,
                                            LPTIME_ZONE_INFORMATION );
static FB_TZFORYEARPROC fb_hDtTzForYear = NULL;
static int              fb_hDtTzForYearChecked = 0;

static FB_TZFORYEARPROC fb_hDtGetTzForYearProc( void )
{
    if( !fb_hDtTzForYearChecked ) {
        HMODULE k32 = GetModuleHandle( "kernel32.dll" );
        if( k32 != NULL )
            fb_hDtTzForYear = (FB_TZFORYEARPROC)(void *)
                GetProcAddress( k32, "GetTimeZoneInformationForYear" );
        fb_hDtTzForYearChecked = 1;
    }
    return fb_hDtTzForYear;
}

static int fb_hDtTziForYear( const SYSTEMTIME *utc, TIME_ZONE_INFORMATION *tzi )
{
    DYNAMIC_TIME_ZONE_INFORMATION dtzi;
    FB_TZFORYEARPROC forYear = fb_hDtGetTzForYearProc( );

    if( forYear != NULL ) {
        if( GetDynamicTimeZoneInformation( &dtzi ) != TIME_ZONE_ID_INVALID ) {
            if( forYear( (USHORT)utc->wYear, &dtzi, tzi ) )
                return 0;
        }
    }
    if( GetTimeZoneInformation( tzi ) != TIME_ZONE_ID_INVALID )
        return 0;
    return 1;
}

static int fb_hDtTicksToSystemTime( long long ticks, SYSTEMTIME *st )
{
    FILETIME ft;
    ULARGE_INTEGER u;

    if( !fb_DtIsValidTicks( ticks ) )
        return 1;
    u.QuadPart = (ULONGLONG)( ticks - FB_DT_TICKS_TO_FILETIME );
    ft.dwLowDateTime = u.LowPart;
    ft.dwHighDateTime = u.HighPart;
    return FileTimeToSystemTime( &ft, st ) ? 0 : 1;
}

/* Offset in minutes east of UTC, AT THE GIVEN INSTANT -- not "right now".
** Converting a July timestamp with January's offset is the single most common
** timezone bug, and an API that only offers the current offset makes it the
** path of least resistance. */
/*:::::*/
FBCALL int fb_DtZoneOffsetAt( long long utcTicks )
{
    SYSTEMTIME utc, local;
    TIME_ZONE_INFORMATION tzi;
    long long lt, ut;
    int y, mo, d, h, mi, s;

    if( fb_hDtTicksToSystemTime( utcTicks, &utc ) )
        return 0;
    if( fb_hDtTziForYear( &utc, &tzi ) )
        return 0;
    if( !SystemTimeToTzSpecificLocalTime( &tzi, &utc, &local ) )
        return 0;

    if( fb_DtFromCivil( local.wYear, local.wMonth, local.wDay,
                        local.wHour, local.wMinute, local.wSecond, 0, &lt ) )
        return 0;
    if( fb_DtFromCivil( utc.wYear, utc.wMonth, utc.wDay,
                        utc.wHour, utc.wMinute, utc.wSecond, 0, &ut ) )
        return 0;
    (void)y; (void)mo; (void)d; (void)h; (void)mi; (void)s;

    return (int)( ( lt - ut ) / FB_DT_TICKS_PER_MINUTE );
}

/*:::::*/
FBCALL int fb_DtZoneIsDst( long long utcTicks )
{
    SYSTEMTIME utc;
    TIME_ZONE_INFORMATION tzi;
    DYNAMIC_TIME_ZONE_INFORMATION dtzi;

    if( fb_hDtTicksToSystemTime( utcTicks, &utc ) )
        return 0;
    if( fb_hDtTziForYear( &utc, &tzi ) )
        return 0;
    (void)dtzi;
    if( tzi.DaylightBias == 0 )
        return 0;
    /* in DST when the offset differs from the standard one */
    return ( fb_DtZoneOffsetAt( utcTicks ) != -tzi.Bias - tzi.StandardBias ) ? 1 : 0;
}

/*:::::*/
FBCALL int fb_DtZoneSupportsDst( void )
{
    TIME_ZONE_INFORMATION tzi;
    if( GetTimeZoneInformation( &tzi ) == TIME_ZONE_ID_INVALID )
        return 0;
    return ( tzi.DaylightBias != 0 ) ? 1 : 0;
}

/*:::::*/
FBCALL int fb_DtZoneStandardName( char *buf, int buflen )
{
    TIME_ZONE_INFORMATION tzi;
    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( GetTimeZoneInformation( &tzi ) == TIME_ZONE_ID_INVALID ) return 0;
    return fb_hDtW2U( tzi.StandardName, buf, buflen );
}

/*:::::*/
FBCALL int fb_DtZoneDaylightName( char *buf, int buflen )
{
    TIME_ZONE_INFORMATION tzi;
    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( GetTimeZoneInformation( &tzi ) == TIME_ZONE_ID_INVALID ) return 0;
    return fb_hDtW2U( tzi.DaylightName, buf, buflen );
}

/* ---------------------------------------------------- locale formatting */
/* Output here is whatever the machine's locale says and CANNOT be asserted by
** exact string.  That is an honest limitation, recorded in RFC-0007 s3, and it
** is exactly why RFC-0006's pattern formatter uses invariant English. */

/*:::::*/
FBCALL int fb_DtLocaleDateString( long long ticks, int style, char *buf, int buflen )
{
    SYSTEMTIME st;
    WCHAR wbuf[256];
    DWORD flags;
    int n;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( !fb_DtIsValidTicks( ticks ) ) return 0;

    {
        int y, mo, d, h, mi, s;
        long long sub;
        fb_DtToCivil( ticks, &y, &mo, &d, &h, &mi, &s, &sub );
        st.wYear = (WORD)y; st.wMonth = (WORD)mo; st.wDay = (WORD)d;
        st.wHour = (WORD)h; st.wMinute = (WORD)mi; st.wSecond = (WORD)s;
        st.wMilliseconds = 0;
        st.wDayOfWeek = (WORD)( fb_DtDayOfWeek( (int)( ticks / FB_DT_TICKS_PER_DAY ) ) % 7 );
    }

    flags = ( style == DT_ZONE_STYLE_SHORT ) ? DATE_SHORTDATE : DATE_LONGDATE;
    n = GetDateFormatEx( LOCALE_NAME_USER_DEFAULT, flags, &st, NULL,
                         wbuf, (int)( sizeof( wbuf ) / sizeof( WCHAR ) ), NULL );
    if( n <= 0 ) return 0;
    return fb_hDtW2U( wbuf, buf, buflen );
}

/*:::::*/
FBCALL int fb_DtLocaleTimeString( long long ticks, int style, char *buf, int buflen )
{
    SYSTEMTIME st;
    WCHAR wbuf[256];
    DWORD flags;
    int n;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( !fb_DtIsValidTicks( ticks ) ) return 0;

    {
        int y, mo, d, h, mi, s;
        long long sub;
        fb_DtToCivil( ticks, &y, &mo, &d, &h, &mi, &s, &sub );
        st.wYear = (WORD)y; st.wMonth = (WORD)mo; st.wDay = (WORD)d;
        st.wHour = (WORD)h; st.wMinute = (WORD)mi; st.wSecond = (WORD)s;
        st.wMilliseconds = 0;
        st.wDayOfWeek = 0;
    }

    flags = ( style == DT_ZONE_STYLE_SHORT ) ? TIME_NOSECONDS : 0;
    n = GetTimeFormatEx( LOCALE_NAME_USER_DEFAULT, flags, &st, NULL,
                         wbuf, (int)( sizeof( wbuf ) / sizeof( WCHAR ) ) );
    if( n <= 0 ) return 0;
    return fb_hDtW2U( wbuf, buf, buflen );
}

/*:::::*/
FBCALL int fb_DtLocaleMonthName( int mo, int abbreviated, char *buf, int buflen )
{
    WCHAR wbuf[128];
    LCTYPE t;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( mo < 1 || mo > 12 ) return 0;

    t = ( abbreviated ? LOCALE_SABBREVMONTHNAME1 : LOCALE_SMONTHNAME1 ) + ( mo - 1 );
    if( GetLocaleInfoEx( LOCALE_NAME_USER_DEFAULT, t, wbuf,
                         (int)( sizeof( wbuf ) / sizeof( WCHAR ) ) ) <= 0 )
        return 0;
    return fb_hDtW2U( wbuf, buf, buflen );
}

/*:::::*/
FBCALL int fb_DtLocaleWeekdayName( int dow, int abbreviated, char *buf, int buflen )
{
    WCHAR wbuf[128];
    LCTYPE t;

    if( buf == NULL || buflen < 2 ) return 0;
    buf[0] = 0;
    if( dow < 1 || dow > 7 ) return 0;

    /* Windows numbers these Monday-first (LOCALE_SDAYNAME1 is Monday), which
    ** happens to match this library's ISO 1..7 convention exactly. */
    t = ( abbreviated ? LOCALE_SABBREVDAYNAME1 : LOCALE_SDAYNAME1 ) + ( dow - 1 );
    if( GetLocaleInfoEx( LOCALE_NAME_USER_DEFAULT, t, wbuf,
                         (int)( sizeof( wbuf ) / sizeof( WCHAR ) ) ) <= 0 )
        return 0;
    return fb_hDtW2U( wbuf, buf, buflen );
}

/*:::::*/
FBCALL int fb_DtLocaleIsSupported( void )
{
    return 1;
}
