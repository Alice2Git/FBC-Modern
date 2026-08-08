/* chrono: ISO 8601 / RFC 3339 formatting and strict parsing.
**
** Specified by docs/datetime/RFC-0005-iso8601.md.
**
** Portable, pure, locale-independent, ASCII-only.  No sprintf anywhere: a
** "%f" picking up a comma decimal point on a European machine is a real bug
** and this file must be byte-identical under every locale.
**
** EMISSION is canonical and single-valued -- one input produces exactly one
** string.  The variety in ISO 8601 is accepted on input only.
**
** PARSING is strict.  The caller states the grammar and gets a failure if the
** input does not match it.  There is no locale, no guessing, and no partial
** acceptance; trailing characters are an error.  The lenient, locale-guessing
** parser in time_parsedate.c is untouched and is not built upon -- see
** docs/datetime/rationale.md.
*/

#include "fb.h"

#define DT_ISO_OFFSET_UNSPECIFIED  32767
#define DT_ISO_OFFSET_LIMIT        1080     /* +/- 18:00 */

/* ------------------------------------------------------------------ emit */

static int fb_hDtPut2( char *buf, int v )
{
    buf[0] = (char)( '0' + ( v / 10 ) % 10 );
    buf[1] = (char)( '0' + v % 10 );
    return 2;
}

static int fb_hDtPut4( char *buf, int v )
{
    buf[0] = (char)( '0' + ( v / 1000 ) % 10 );
    buf[1] = (char)( '0' + ( v / 100 ) % 10 );
    buf[2] = (char)( '0' + ( v / 10 ) % 10 );
    buf[3] = (char)( '0' + v % 10 );
    return 4;
}

/* Exactly seven digits, zero-padded, no trailing-zero trimming.  Fixed width
** is what makes the output lexicographically sortable, which is the property
** that matters when these strings land in a log or a database key. */
static int fb_hDtPut7( char *buf, long long v )
{
    int i;
    for( i = 6; i >= 0; i-- ) {
        buf[i] = (char)( '0' + (int)( v % 10 ) );
        v /= 10;
    }
    return 7;
}

/* Offset as Z (UTC) or +/-HH:MM.  Unspecified emits nothing. */
static int fb_hDtPutOffset( char *buf, int offMin )
{
    int n = 0, a;

    if( offMin == DT_ISO_OFFSET_UNSPECIFIED )
        return 0;
    if( offMin == 0 ) {
        buf[0] = 'Z';
        return 1;
    }

    buf[n++] = ( offMin < 0 ) ? '-' : '+';
    a = ( offMin < 0 ) ? -offMin : offMin;
    n += fb_hDtPut2( buf + n, a / 60 );
    buf[n++] = ':';
    n += fb_hDtPut2( buf + n, a % 60 );
    return n;
}

/*:::::*/
FBCALL int fb_DtIsoFormatDate( int days, char *buf, int buflen )
{
    int y, mo, d, n = 0;

    if( buf == NULL || buflen < 11 )
        return 0;
    if( days < FB_DT_MIN_DAYS || days > FB_DT_MAX_DAYS ) {
        buf[0] = 0;
        return 0;
    }

    fb_DtCivilFromDays( days, &y, &mo, &d );
    n += fb_hDtPut4( buf + n, y );
    buf[n++] = '-';
    n += fb_hDtPut2( buf + n, mo );
    buf[n++] = '-';
    n += fb_hDtPut2( buf + n, d );
    buf[n] = 0;
    return n;
}

/*:::::*/
FBCALL int fb_DtIsoFormatTime( long long tod, char *buf, int buflen )
{
    long long sub;
    int n = 0;

    if( buf == NULL || buflen < 17 )
        return 0;
    if( tod < 0 || tod >= FB_DT_TICKS_PER_DAY ) {
        buf[0] = 0;
        return 0;
    }

    n += fb_hDtPut2( buf + n, (int)( tod / FB_DT_TICKS_PER_HOUR ) );
    buf[n++] = ':';
    n += fb_hDtPut2( buf + n, (int)( tod / FB_DT_TICKS_PER_MINUTE % 60 ) );
    buf[n++] = ':';
    n += fb_hDtPut2( buf + n, (int)( tod / FB_DT_TICKS_PER_SECOND % 60 ) );

    /* The fraction is omitted ENTIRELY when zero, and otherwise is exactly
    ** seven digits. */
    sub = tod % FB_DT_TICKS_PER_SECOND;
    if( sub != 0 ) {
        buf[n++] = '.';
        n += fb_hDtPut7( buf + n, sub );
    }
    buf[n] = 0;
    return n;
}

/*:::::*/
FBCALL int fb_DtIsoFormat( long long ticks, int offMin, char *buf, int buflen )
{
    int n;

    if( buf == NULL || buflen < 34 )
        return 0;
    if( !fb_DtIsValidTicks( ticks ) ) {
        buf[0] = 0;
        return 0;
    }

    n = fb_DtIsoFormatDate( (int)( ticks / FB_DT_TICKS_PER_DAY ), buf, buflen );
    if( n == 0 )
        return 0;
    buf[n++] = 'T';
    n += fb_DtIsoFormatTime( ticks % FB_DT_TICKS_PER_DAY, buf + n, buflen - n );
    n += fb_hDtPutOffset( buf + n, offMin );
    buf[n] = 0;
    return n;
}

/* ISO 8601 duration.  Unlike the timestamp forms, the seconds fraction here
** IS trimmed of trailing zeros -- durations are not sorted as strings, so
** fixed width buys nothing.  RFC-0005 section 5. */
/*:::::*/
FBCALL int fb_DtIsoFormatDuration( long long ticks, char *buf, int buflen )
{
    long long days, h, m, s, sub;
    int n = 0, i;
    char frac[8];

    if( buf == NULL || buflen < 40 )
        return 0;
    if( ticks == FB_DT_INVALID_TICKS ) {
        buf[0] = 0;
        return 0;
    }

    if( ticks < 0 ) {
        buf[n++] = '-';
        ticks = -ticks;
    }
    buf[n++] = 'P';

    days = ticks / FB_DT_TICKS_PER_DAY;
    ticks %= FB_DT_TICKS_PER_DAY;
    h = ticks / FB_DT_TICKS_PER_HOUR;
    ticks %= FB_DT_TICKS_PER_HOUR;
    m = ticks / FB_DT_TICKS_PER_MINUTE;
    ticks %= FB_DT_TICKS_PER_MINUTE;
    s = ticks / FB_DT_TICKS_PER_SECOND;
    sub = ticks % FB_DT_TICKS_PER_SECOND;

    if( days != 0 ) {
        char tmp[24];
        int k = 0;
        long long v = days;
        while( v > 0 ) { tmp[k++] = (char)( '0' + (int)( v % 10 ) ); v /= 10; }
        while( k > 0 ) buf[n++] = tmp[--k];
        buf[n++] = 'D';
    }

    if( h != 0 || m != 0 || s != 0 || sub != 0 ) {
        buf[n++] = 'T';
        if( h != 0 ) {
            char tmp[8];
            int k = 0;
            long long v = h;
            while( v > 0 ) { tmp[k++] = (char)( '0' + (int)( v % 10 ) ); v /= 10; }
            while( k > 0 ) buf[n++] = tmp[--k];
            buf[n++] = 'H';
        }
        if( m != 0 ) {
            if( m >= 10 ) buf[n++] = (char)( '0' + (int)( m / 10 ) );
            buf[n++] = (char)( '0' + (int)( m % 10 ) );
            buf[n++] = 'M';
        }
        if( s != 0 || sub != 0 ) {
            if( s >= 10 ) buf[n++] = (char)( '0' + (int)( s / 10 ) );
            buf[n++] = (char)( '0' + (int)( s % 10 ) );
            if( sub != 0 ) {
                fb_hDtPut7( frac, sub );
                i = 7;
                while( i > 1 && frac[i - 1] == '0' )
                    i--;
                buf[n++] = '.';
                {
                    int j;
                    for( j = 0; j < i; j++ )
                        buf[n++] = frac[j];
                }
            }
            buf[n++] = 'S';
        }
    }

    /* a bare "P" is not a duration; zero is PT0S */
    if( n == 1 || ( n == 2 && buf[0] == '-' ) ) {
        n = 0;
        buf[n++] = 'P';
        buf[n++] = 'T';
        buf[n++] = '0';
        buf[n++] = 'S';
    }

    buf[n] = 0;
    return n;
}

/* ----------------------------------------------------------------- parse */

typedef struct _FB_DTSCAN {
    const char *p;
    const char *end;
} FB_DTSCAN;

static int fb_hDtIsDigit( char c )
{
    return ( c >= '0' && c <= '9' );
}

static int fb_hDtRemaining( FB_DTSCAN *sc )
{
    return (int)( sc->end - sc->p );
}

/* Count consecutive digits at the cursor without consuming. */
static int fb_hDtDigitRun( FB_DTSCAN *sc )
{
    const char *q = sc->p;
    while( q < sc->end && fb_hDtIsDigit( *q ) )
        q++;
    return (int)( q - sc->p );
}

/* Read exactly n digits.  Fails if fewer are present. */
static int fb_hDtFixed( FB_DTSCAN *sc, int n, int *out )
{
    int v = 0, i;
    if( fb_hDtRemaining( sc ) < n )
        return 1;
    for( i = 0; i < n; i++ ) {
        if( !fb_hDtIsDigit( sc->p[i] ) )
            return 1;
        v = v * 10 + ( sc->p[i] - '0' );
    }
    sc->p += n;
    *out = v;
    return 0;
}

/* ISO week date -> days since 0001-01-01. */
static int fb_hDtDaysFromIsoWeek( int isoYear, int week, int dow, int *out )
{
    int jan4, week1Monday;

    if( isoYear < FB_DT_MIN_YEAR || isoYear > FB_DT_MAX_YEAR )
        return 1;
    if( week < 1 || week > fb_DtIsoWeeksInYear( isoYear ) )
        return 1;
    if( dow < 1 || dow > 7 )
        return 1;

    /* Week 1 is the week containing 4 January, by definition. */
    jan4 = fb_DtDaysFromCivil( isoYear, 1, 4 );
    week1Monday = jan4 - ( fb_DtDayOfWeek( jan4 ) - 1 );

    *out = week1Monday + ( week - 1 ) * 7 + ( dow - 1 );
    if( *out < FB_DT_MIN_DAYS || *out > FB_DT_MAX_DAYS )
        return 1;
    return 0;
}

/* A date in any of the four accepted shapes. */
static int fb_hDtScanDate( FB_DTSCAN *sc, int *out_days )
{
    int y, mo, d, run;

    if( fb_hDtFixed( sc, 4, &y ) )
        return 1;
    if( y < FB_DT_MIN_YEAR || y > FB_DT_MAX_YEAR )
        return 1;

    if( fb_hDtRemaining( sc ) > 0 && *sc->p == '-' ) {
        sc->p++;
        if( fb_hDtRemaining( sc ) > 0 && ( *sc->p == 'W' || *sc->p == 'w' ) ) {
            int wk, dow;
            sc->p++;
            if( fb_hDtFixed( sc, 2, &wk ) )
                return 1;
            if( fb_hDtRemaining( sc ) == 0 || *sc->p != '-' )
                return 1;
            sc->p++;
            if( fb_hDtFixed( sc, 1, &dow ) )
                return 1;
            return fb_hDtDaysFromIsoWeek( y, wk, dow, out_days );
        }
        run = fb_hDtDigitRun( sc );
        if( run == 3 ) {
            /* ordinal date YYYY-DDD */
            int doy;
            if( fb_hDtFixed( sc, 3, &doy ) )
                return 1;
            if( doy < 1 || doy > fb_DtDaysInYear( y ) )
                return 1;
            *out_days = fb_DtDaysFromCivil( y, 1, 1 ) + doy - 1;
            return 0;
        }
        if( fb_hDtFixed( sc, 2, &mo ) )
            return 1;
        if( fb_hDtRemaining( sc ) == 0 || *sc->p != '-' )
            return 1;
        sc->p++;
        if( fb_hDtFixed( sc, 2, &d ) )
            return 1;
        if( !fb_DtIsValidDate( y, mo, d ) )
            return 1;
        *out_days = fb_DtDaysFromCivil( y, mo, d );
        return 0;
    }

    if( fb_hDtRemaining( sc ) > 0 && ( *sc->p == 'W' || *sc->p == 'w' ) ) {
        int wk, dow;
        sc->p++;
        if( fb_hDtFixed( sc, 2, &wk ) )
            return 1;
        if( fb_hDtFixed( sc, 1, &dow ) )
            return 1;
        return fb_hDtDaysFromIsoWeek( y, wk, dow, out_days );
    }

    /* basic format: YYYYMMDD or YYYYDDD */
    run = fb_hDtDigitRun( sc );
    if( run == 4 ) {
        if( fb_hDtFixed( sc, 2, &mo ) )
            return 1;
        if( fb_hDtFixed( sc, 2, &d ) )
            return 1;
        if( !fb_DtIsValidDate( y, mo, d ) )
            return 1;
        *out_days = fb_DtDaysFromCivil( y, mo, d );
        return 0;
    }
    if( run == 3 ) {
        int doy;
        if( fb_hDtFixed( sc, 3, &doy ) )
            return 1;
        if( doy < 1 || doy > fb_DtDaysInYear( y ) )
            return 1;
        *out_days = fb_DtDaysFromCivil( y, 1, 1 ) + doy - 1;
        return 0;
    }
    return 1;
}

/* A time of day.  Returns ticks-of-day. */
static int fb_hDtScanTime( FB_DTSCAN *sc, long long *out_tod )
{
    int h, m = 0, s = 0, extended, run;
    long long sub = 0;

    if( fb_hDtFixed( sc, 2, &h ) )
        return 1;

    extended = ( fb_hDtRemaining( sc ) > 0 && *sc->p == ':' );
    if( extended ) {
        sc->p++;
        if( fb_hDtFixed( sc, 2, &m ) )
            return 1;
        if( fb_hDtRemaining( sc ) > 0 && *sc->p == ':' ) {
            sc->p++;
            if( fb_hDtFixed( sc, 2, &s ) )
                return 1;
        }
    } else {
        run = fb_hDtDigitRun( sc );
        if( run >= 2 ) {
            if( fb_hDtFixed( sc, 2, &m ) )
                return 1;
            run = fb_hDtDigitRun( sc );
            if( run >= 2 ) {
                if( fb_hDtFixed( sc, 2, &s ) )
                    return 1;
            }
        }
    }

    /* Fraction: '.' or ',' -- the comma is the ISO 8601 preferred form and
    ** appears in European data. */
    if( fb_hDtRemaining( sc ) > 0 && ( *sc->p == '.' || *sc->p == ',' ) ) {
        int i = 0;
        sc->p++;
        if( fb_hDtRemaining( sc ) == 0 || !fb_hDtIsDigit( *sc->p ) )
            return 1;
        /* Up to seven digits are significant; anything beyond is TRUNCATED,
        ** not rejected, so nanosecond timestamps from Go or Rust still parse.
        ** RFC-0005 section 2. */
        while( fb_hDtRemaining( sc ) > 0 && fb_hDtIsDigit( *sc->p ) ) {
            if( i < 7 )
                sub = sub * 10 + ( *sc->p - '0' );
            i++;
            sc->p++;
        }
        while( i < 7 ) {
            sub *= 10;
            i++;
        }
    }

    /* 24:00 is legal ISO 8601 and is a landmine; the value it denotes is the
    ** next day's 00:00 and the caller should say so.  Leap seconds are out of
    ** scope, so :60 is rejected too. */
    if( h > 23 || m > 59 || s > 59 )
        return 1;

    *out_tod = (long long)h * FB_DT_TICKS_PER_HOUR
             + (long long)m * FB_DT_TICKS_PER_MINUTE
             + (long long)s * FB_DT_TICKS_PER_SECOND
             + sub;
    return 0;
}

static int fb_hDtScanOffset( FB_DTSCAN *sc, int *out_off )
{
    int sign, hh, mm = 0;

    if( fb_hDtRemaining( sc ) == 0 ) {
        *out_off = DT_ISO_OFFSET_UNSPECIFIED;
        return 0;
    }

    if( *sc->p == 'Z' || *sc->p == 'z' ) {
        sc->p++;
        *out_off = 0;
        return 0;
    }

    if( *sc->p != '+' && *sc->p != '-' ) {
        *out_off = DT_ISO_OFFSET_UNSPECIFIED;
        return 0;
    }

    sign = ( *sc->p == '-' ) ? -1 : 1;
    sc->p++;
    if( fb_hDtFixed( sc, 2, &hh ) )
        return 1;
    if( fb_hDtRemaining( sc ) > 0 && *sc->p == ':' ) {
        sc->p++;
        if( fb_hDtFixed( sc, 2, &mm ) )
            return 1;
    } else if( fb_hDtDigitRun( sc ) >= 2 ) {
        if( fb_hDtFixed( sc, 2, &mm ) )
            return 1;
    }

    if( mm > 59 )
        return 1;
    *out_off = sign * ( hh * 60 + mm );
    if( *out_off < -DT_ISO_OFFSET_LIMIT || *out_off > DT_ISO_OFFSET_LIMIT )
        return 1;
    return 0;
}

/* Trim leading and trailing ASCII whitespace.  Interior whitespace, other than
** the single RFC 3339 space separator, is an error. */
static void fb_hDtTrim( FB_DTSCAN *sc )
{
    while( sc->p < sc->end &&
           ( *sc->p == ' ' || *sc->p == '\t' || *sc->p == '\r' || *sc->p == '\n' ) )
        sc->p++;
    while( sc->end > sc->p &&
           ( sc->end[-1] == ' ' || sc->end[-1] == '\t' ||
             sc->end[-1] == '\r' || sc->end[-1] == '\n' ) )
        sc->end--;
}

/*:::::*/
FBCALL int fb_DtIsoParse( const char *s, int len, long long *out_ticks, int *out_off )
{
    FB_DTSCAN sc;
    int days = 0, off = DT_ISO_OFFSET_UNSPECIFIED;
    long long tod = 0, ticks;

    if( out_ticks != NULL ) *out_ticks = FB_DT_INVALID_TICKS;
    if( out_off != NULL )   *out_off = DT_ISO_OFFSET_UNSPECIFIED;
    if( s == NULL || len <= 0 )
        return 1;

    sc.p = s;
    sc.end = s + len;
    fb_hDtTrim( &sc );
    if( fb_hDtRemaining( &sc ) == 0 )
        return 1;

    if( fb_hDtScanDate( &sc, &days ) )
        return 1;

    if( fb_hDtRemaining( &sc ) > 0 ) {
        char c = *sc.p;
        /* 'T', 't', or -- per RFC 3339 section 5.6 -- a single space, which is
        ** what every SQL database emits. */
        if( c == 'T' || c == 't' || c == ' ' ) {
            sc.p++;
            if( fb_hDtScanTime( &sc, &tod ) )
                return 1;
            if( fb_hDtScanOffset( &sc, &off ) )
                return 1;
        } else {
            return 1;
        }
    }

    /* trailing garbage is an error */
    if( fb_hDtRemaining( &sc ) != 0 )
        return 1;

    ticks = (long long)days * FB_DT_TICKS_PER_DAY + tod;
    if( !fb_DtIsValidTicks( ticks ) )
        return 1;

    if( out_ticks != NULL ) *out_ticks = ticks;
    if( out_off != NULL )   *out_off = off;
    return 0;
}

/*:::::*/
FBCALL int fb_DtIsoParseDate( const char *s, int len, int *out_days )
{
    FB_DTSCAN sc;
    int days = 0;

    if( out_days != NULL ) *out_days = -1;
    if( s == NULL || len <= 0 )
        return 1;

    sc.p = s;
    sc.end = s + len;
    fb_hDtTrim( &sc );
    if( fb_hDtRemaining( &sc ) == 0 )
        return 1;
    if( fb_hDtScanDate( &sc, &days ) )
        return 1;
    if( fb_hDtRemaining( &sc ) != 0 )
        return 1;

    if( out_days != NULL ) *out_days = days;
    return 0;
}

/*:::::*/
FBCALL int fb_DtIsoParseTime( const char *s, int len, long long *out_tod )
{
    FB_DTSCAN sc;
    long long tod = 0;

    if( out_tod != NULL ) *out_tod = FB_DT_INVALID_TICKS;
    if( s == NULL || len <= 0 )
        return 1;

    sc.p = s;
    sc.end = s + len;
    fb_hDtTrim( &sc );
    if( fb_hDtRemaining( &sc ) == 0 )
        return 1;
    if( fb_hDtScanTime( &sc, &tod ) )
        return 1;
    if( fb_hDtRemaining( &sc ) != 0 )
        return 1;

    if( out_tod != NULL ) *out_tod = tod;
    return 0;
}

/* ISO 8601 duration.  Years and months are REJECTED: a TimeSpan is a fixed
** duration and a month has no fixed length, so accepting P1M would mean
** inventing one.  Weeks are accepted on input and become 7 days. */
/*:::::*/
FBCALL int fb_DtIsoParseDuration( const char *s, int len, long long *out_ticks )
{
    FB_DTSCAN sc;
    long long total = 0;
    int neg = 0, inTime = 0, sawAny = 0;

    if( out_ticks != NULL ) *out_ticks = FB_DT_INVALID_TICKS;
    if( s == NULL || len <= 0 )
        return 1;

    sc.p = s;
    sc.end = s + len;
    fb_hDtTrim( &sc );
    if( fb_hDtRemaining( &sc ) == 0 )
        return 1;

    if( *sc.p == '-' ) {
        neg = 1;
        sc.p++;
    } else if( *sc.p == '+' ) {
        sc.p++;
    }

    if( fb_hDtRemaining( &sc ) == 0 )
        return 1;
    if( *sc.p != 'P' && *sc.p != 'p' )
        return 1;
    sc.p++;

    while( fb_hDtRemaining( &sc ) > 0 ) {
        long long v = 0, frac = 0;
        int nd = 0, hasFrac = 0;
        char unit;

        if( *sc.p == 'T' || *sc.p == 't' ) {
            inTime = 1;
            sc.p++;
            continue;
        }

        while( fb_hDtRemaining( &sc ) > 0 && fb_hDtIsDigit( *sc.p ) ) {
            if( v > 1000000000000ll )
                return 1;
            v = v * 10 + ( *sc.p - '0' );
            nd++;
            sc.p++;
        }
        if( nd == 0 )
            return 1;

        if( fb_hDtRemaining( &sc ) > 0 && ( *sc.p == '.' || *sc.p == ',' ) ) {
            int i = 0;
            sc.p++;
            if( fb_hDtRemaining( &sc ) == 0 || !fb_hDtIsDigit( *sc.p ) )
                return 1;
            hasFrac = 1;
            while( fb_hDtRemaining( &sc ) > 0 && fb_hDtIsDigit( *sc.p ) ) {
                if( i < 7 )
                    frac = frac * 10 + ( *sc.p - '0' );
                i++;
                sc.p++;
            }
            while( i < 7 ) {
                frac *= 10;
                i++;
            }
        }

        if( fb_hDtRemaining( &sc ) == 0 )
            return 1;
        unit = *sc.p;
        sc.p++;

        if( hasFrac && !( inTime && ( unit == 'S' || unit == 's' ) ) )
            return 1;

        switch( unit ) {
        case 'W': case 'w':
            if( inTime ) return 1;
            total += v * 7ll * FB_DT_TICKS_PER_DAY;
            break;
        case 'D': case 'd':
            if( inTime ) return 1;
            total += v * FB_DT_TICKS_PER_DAY;
            break;
        case 'H': case 'h':
            if( !inTime ) return 1;
            total += v * FB_DT_TICKS_PER_HOUR;
            break;
        case 'S': case 's':
            if( !inTime ) return 1;
            total += v * FB_DT_TICKS_PER_SECOND + frac;
            break;
        case 'M': case 'm':
            /* 'M' before T is MONTHS, which is not a fixed duration. */
            if( !inTime ) return 1;
            total += v * FB_DT_TICKS_PER_MINUTE;
            break;
        case 'Y': case 'y':
            return 1;
        default:
            return 1;
        }
        sawAny = 1;
    }

    if( !sawAny )       /* a bare "P" is an error */
        return 1;

    if( out_ticks != NULL )
        *out_ticks = neg ? -total : total;
    return 0;
}
