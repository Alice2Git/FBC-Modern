/* chrono: custom pattern formatting and strict parsing.
**
** Specified by docs/datetime/RFC-0006-patterns.md.
**
** Pattern letters (yyyy-MM-dd HH:mm:ss), the .NET/Java family, chosen because
** it is what C#, Java, Rust's chrono, ICU and every spreadsheet use, and it is
** closest to the Win32 picture masks the existing FB/AfxNova audience already
** reads.
**
** Output here depends ONLY on the value and the pattern.  Month and day names
** are INVARIANT ENGLISH from the tables below, not the OS locale -- that is
** the whole point of this file.  A pattern formatter whose output changes with
** the machine's locale cannot be used to write a file.  Locale-dependent
** formatting is RFC-0007 and lives elsewhere.
**
** No sprintf, no locale, no allocation.
*/

#include "fb.h"

#define DT_PAT_OFFSET_UNSPECIFIED  32767
#define DT_PAT_ERR                 (-1)

static const char *fb_hDtMonthFull[12] = {
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December" };
static const char *fb_hDtMonthAbbr[12] = {
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };
/* index 0 = Monday, matching the ISO 1..7 convention of RFC-0001 */
static const char *fb_hDtDayFull[7] = {
    "Monday", "Tuesday", "Wednesday", "Thursday",
    "Friday", "Saturday", "Sunday" };
static const char *fb_hDtDayAbbr[7] = {
    "Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun" };

static int fb_hDtPatIsAlpha( char c )
{
    return ( c >= 'a' && c <= 'z' ) || ( c >= 'A' && c <= 'Z' );
}

static int fb_hDtPatIsDigit( char c )
{
    return ( c >= '0' && c <= '9' );
}

/* Length of the run of identical characters starting at p. */
static int fb_hDtPatRun( const char *p, const char *end )
{
    const char *q = p;
    while( q < end && *q == *p )
        q++;
    return (int)( q - p );
}

static int fb_hDtPatNum( char *buf, long long v, int minDigits )
{
    char tmp[24];
    int k = 0, n = 0;

    if( v == 0 )
        tmp[k++] = '0';
    while( v > 0 ) {
        tmp[k++] = (char)( '0' + (int)( v % 10 ) );
        v /= 10;
    }
    while( k < minDigits )
        tmp[k++] = '0';
    while( k > 0 )
        buf[n++] = tmp[--k];
    return n;
}

static int fb_hDtPatStr( char *buf, const char *s )
{
    int n = 0;
    while( *s )
        buf[n++] = *s++;
    return n;
}

/* ---------------------------------------------------------------- format */

/* Returns characters written, or DT_PAT_ERR on a pattern error. */
static int fb_hDtPatFormatCore( long long ticks, int offMin,
                                const char *pat, int patlen,
                                char *buf, int buflen )
{
    const char *p = pat, *pend = pat + patlen;
    int n = 0;
    int y, mo, d, h, mi, s;
    long long sub;
    int days = (int)( ticks / FB_DT_TICKS_PER_DAY );

    fb_DtToCivil( ticks, &y, &mo, &d, &h, &mi, &s, &sub );

    while( p < pend ) {
        char c = *p;
        int run;

        if( n + 64 > buflen )
            return DT_PAT_ERR;

        /* single quotes delimit a literal run; '' inside is one apostrophe */
        if( c == '\'' ) {
            p++;
            for( ;; ) {
                if( p >= pend )
                    return DT_PAT_ERR;          /* unterminated quote */
                if( *p == '\'' ) {
                    p++;
                    if( p < pend && *p == '\'' ) {
                        buf[n++] = '\'';
                        p++;
                        continue;
                    }
                    break;
                }
                buf[n++] = *p++;
                if( n + 8 > buflen )
                    return DT_PAT_ERR;
            }
            continue;
        }

        /* backslash escapes exactly the next character */
        if( c == '\\' ) {
            p++;
            if( p >= pend )
                return DT_PAT_ERR;
            buf[n++] = *p++;
            continue;
        }

        /* anything that is not a pattern letter is a literal */
        if( !fb_hDtPatIsAlpha( c ) ) {
            buf[n++] = c;
            p++;
            continue;
        }

        run = fb_hDtPatRun( p, pend );
        p += run;

        switch( c ) {
        case 'y':
            if( run == 2 )       n += fb_hDtPatNum( buf + n, y % 100, 2 );
            else if( run == 1 )  n += fb_hDtPatNum( buf + n, y, 1 );
            else                 n += fb_hDtPatNum( buf + n, y, run );
            break;
        case 'M':
            if( run == 1 )       n += fb_hDtPatNum( buf + n, mo, 1 );
            else if( run == 2 )  n += fb_hDtPatNum( buf + n, mo, 2 );
            else if( run == 3 )  n += fb_hDtPatStr( buf + n, fb_hDtMonthAbbr[mo - 1] );
            else if( run == 4 )  n += fb_hDtPatStr( buf + n, fb_hDtMonthFull[mo - 1] );
            else                 return DT_PAT_ERR;
            break;
        case 'd':
            if( run == 1 )       n += fb_hDtPatNum( buf + n, d, 1 );
            else if( run == 2 )  n += fb_hDtPatNum( buf + n, d, 2 );
            else if( run == 3 )  n += fb_hDtPatStr( buf + n, fb_hDtDayAbbr[fb_DtDayOfWeek( days ) - 1] );
            else if( run == 4 )  n += fb_hDtPatStr( buf + n, fb_hDtDayFull[fb_DtDayOfWeek( days ) - 1] );
            else                 return DT_PAT_ERR;
            break;
        case 'D':
            n += fb_hDtPatNum( buf + n, fb_DtDayOfYear( y, mo, d ), run );
            break;
        case 'Q':
            if( run != 1 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, ( mo - 1 ) / 3 + 1, 1 );
            break;
        case 'w':
            if( run > 2 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, fb_DtIsoWeek( y, mo, d, NULL ), run );
            break;
        case 'Y': {
            int iy = y;
            fb_DtIsoWeek( y, mo, d, &iy );
            n += fb_hDtPatNum( buf + n, iy, run );
            break;
        }
        case 'g':
            n += fb_hDtPatStr( buf + n, "A.D." );
            break;
        case 'H':
            if( run > 2 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, h, run );
            break;
        case 'h': {
            int h12 = h % 12;
            if( h12 == 0 ) h12 = 12;          /* 00:00 is 12 AM, 12:00 is 12 PM */
            if( run > 2 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, h12, run );
            break;
        }
        case 'm':
            if( run > 2 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, mi, run );
            break;
        case 's':
            if( run > 2 ) return DT_PAT_ERR;
            n += fb_hDtPatNum( buf + n, s, run );
            break;
        case 'f': {
            /* fixed width, zero-padded, always shown */
            long long v = sub;
            int i;
            if( run > 7 ) return DT_PAT_ERR;
            for( i = 7; i > run; i-- )
                v /= 10;
            n += fb_hDtPatNum( buf + n, v, run );
            break;
        }
        case 'F': {
            /* trailing zeros trimmed; the whole field vanishes when zero */
            long long v = sub;
            int i, w = run;
            if( run > 7 ) return DT_PAT_ERR;
            for( i = 7; i > run; i-- )
                v /= 10;
            while( w > 0 && ( v % 10 ) == 0 ) {
                v /= 10;
                w--;
            }
            if( w > 0 ) {
                n += fb_hDtPatNum( buf + n, v, w );
            } else if( n > 0 && buf[n - 1] == '.' ) {
                /* the field vanished, and it takes the decimal point with it
                ** -- otherwise "HH:mm:ss.FFF" leaves a trailing dot */
                n--;
            }
            break;
        }
        case 't':
            if( run == 1 )       buf[n++] = ( h < 12 ) ? 'A' : 'P';
            else if( run == 2 ) { buf[n++] = ( h < 12 ) ? 'A' : 'P'; buf[n++] = 'M'; }
            else                 return DT_PAT_ERR;
            break;
        case 'z': {
            int a, sign;
            if( offMin == DT_PAT_OFFSET_UNSPECIFIED )
                break;
            sign = ( offMin < 0 );
            a = sign ? -offMin : offMin;
            buf[n++] = sign ? '-' : '+';
            if( run == 1 )      n += fb_hDtPatNum( buf + n, a / 60, 1 );
            else if( run == 2 ) n += fb_hDtPatNum( buf + n, a / 60, 2 );
            else if( run == 3 ) {
                n += fb_hDtPatNum( buf + n, a / 60, 2 );
                buf[n++] = ':';
                n += fb_hDtPatNum( buf + n, a % 60, 2 );
            } else return DT_PAT_ERR;
            break;
        }
        case 'K':
            if( run != 1 ) return DT_PAT_ERR;
            if( offMin == DT_PAT_OFFSET_UNSPECIFIED )
                break;                          /* emits nothing */
            if( offMin == 0 ) {
                buf[n++] = 'Z';
            } else {
                int sign = ( offMin < 0 );
                int a = sign ? -offMin : offMin;
                buf[n++] = sign ? '-' : '+';
                n += fb_hDtPatNum( buf + n, a / 60, 2 );
                buf[n++] = ':';
                n += fb_hDtPatNum( buf + n, a % 60, 2 );
            }
            break;
        default:
            /* An unrecognised letter is a PATTERN ERROR, not a literal.
            ** Silently passing it through turns a typo into wrong output;
            ** failing turns it into a caught bug. */
            return DT_PAT_ERR;
        }
    }

    return n;
}

/* Shift a value to UTC for the "u" and "R" constant formats.  A value with no
** offset is taken at face value rather than guessed at. */
static long long fb_hDtPatToUtc( long long ticks, int offMin )
{
    long long r;
    if( offMin == DT_PAT_OFFSET_UNSPECIFIED || offMin == 0 )
        return ticks;
    r = ticks - (long long)offMin * FB_DT_TICKS_PER_MINUTE;
    if( !fb_DtIsValidTicks( r ) )
        return ticks;
    return r;
}

/*:::::*/
FBCALL int fb_DtPatFormat( long long ticks, int offMin,
                           const char *pat, int patlen,
                           char *buf, int buflen )
{
    if( buf == NULL || buflen < 8 )
        return DT_PAT_ERR;
    buf[0] = 0;
    if( pat == NULL || patlen < 0 )
        return DT_PAT_ERR;
    if( !fb_DtIsValidTicks( ticks ) )
        return DT_PAT_ERR;

    /* A one-character pattern is a NAMED format, not a field.  This is the
    ** known wart inherited from C#; the shorthands are worth it. */
    if( patlen == 1 ) {
        const char *expand = NULL;
        int n;
        switch( pat[0] ) {
        case 'o': case 'O':
            /* must be byte-identical to RFC-0005 emission -- one
            ** implementation, two entry points */
            return fb_DtIsoFormat( ticks, offMin, buf, buflen );
        case 's': expand = "yyyy-MM-dd'T'HH:mm:ss"; break;
        case 'd': expand = "yyyy-MM-dd"; break;
        case 'T': expand = "HH:mm:ss"; break;
        case 'u':
            ticks = fb_hDtPatToUtc( ticks, offMin );
            expand = "yyyy-MM-dd HH:mm:ss'Z'";
            break;
        case 'R':
            /* RFC 1123, for HTTP headers: always GMT, always English, and the
            ** value is converted to UTC first.  Getting that wrong is the
            ** classic HTTP-header bug. */
            ticks = fb_hDtPatToUtc( ticks, offMin );
            expand = "ddd, dd MMM yyyy HH:mm:ss 'GMT'";
            break;
        default:
            expand = NULL;
            break;
        }
        if( expand != NULL ) {
            int L = 0;
            while( expand[L] ) L++;
            n = fb_hDtPatFormatCore( ticks, offMin, expand, L, buf, buflen );
            if( n < 0 ) { buf[0] = 0; return DT_PAT_ERR; }
            buf[n] = 0;
            return n;
        }
    }

    {
        int n = fb_hDtPatFormatCore( ticks, offMin, pat, patlen, buf, buflen );
        if( n < 0 ) { buf[0] = 0; return DT_PAT_ERR; }
        buf[n] = 0;
        return n;
    }
}

/* ----------------------------------------------------------------- parse */

typedef struct _FB_DTPARTS {
    int year, month, day;
    int hour24, hour12, minute, second;
    long long sub;
    int ampm;           /* -1 none, 0 AM, 1 PM */
    int off;
    int doy;
    int wday;           /* from ddd / dddd, for the cross-check */
    int hasYear, hasMonth, hasDay, hasHour24, hasHour12;
    int hasMin, hasSec, hasDoy;
} FB_DTPARTS;

/* Set a field, failing if it is already set to a DIFFERENT value.  Repeating
** a field consistently is fine; contradicting it is not. */
static int fb_hDtSet( int *slot, int *has, int v )
{
    if( *has && *slot != v )
        return 1;
    *slot = v;
    *has = 1;
    return 0;
}

static int fb_hDtMatchName( const char *s, int slen, int *pos,
                            const char **tbl, int cnt, int *out )
{
    int i, j;
    for( i = 0; i < cnt; i++ ) {
        const char *w = tbl[i];
        j = 0;
        while( w[j] ) {
            char a, b;
            if( *pos + j >= slen ) break;
            a = s[*pos + j];
            b = w[j];
            if( a >= 'A' && a <= 'Z' ) a = (char)( a - 'A' + 'a' );
            if( b >= 'A' && b <= 'Z' ) b = (char)( b - 'A' + 'a' );
            if( a != b ) break;
            j++;
        }
        if( w[j] == 0 ) {
            *pos += j;
            *out = i + 1;
            return 0;
        }
    }
    return 1;
}

/* Read digits: exactly `fixed` of them when fixed > 0, otherwise 1..maxd. */
static int fb_hDtReadNum( const char *s, int slen, int *pos,
                          int fixed, int maxd, int *out )
{
    int v = 0, n = 0;
    if( fixed > 0 ) {
        int i;
        if( *pos + fixed > slen ) return 1;
        for( i = 0; i < fixed; i++ ) {
            if( !fb_hDtPatIsDigit( s[*pos + i] ) ) return 1;
            v = v * 10 + ( s[*pos + i] - '0' );
        }
        *pos += fixed;
        *out = v;
        return 0;
    }
    while( *pos < slen && n < maxd && fb_hDtPatIsDigit( s[*pos] ) ) {
        v = v * 10 + ( s[*pos] - '0' );
        (*pos)++;
        n++;
    }
    if( n == 0 ) return 1;
    *out = v;
    return 0;
}

/* Does the pattern token starting at p consume digits? Used for the
** adjacent-variable-width-numeric ambiguity check. */
static int fb_hDtPatTokenIsNumeric( const char *p, const char *pend )
{
    if( p >= pend ) return 0;
    switch( *p ) {
    case 'y': case 'M': case 'd': case 'D': case 'Q': case 'w': case 'Y':
    case 'H': case 'h': case 'm': case 's': case 'f': case 'F':
        /* MMM and dddd are names, not numbers */
        if( *p == 'M' && fb_hDtPatRun( p, pend ) >= 3 ) return 0;
        if( *p == 'd' && fb_hDtPatRun( p, pend ) >= 3 ) return 0;
        return 1;
    default:
        return 0;
    }
}

/*:::::*/
FBCALL int fb_DtPatParse( const char *s, int slen,
                          const char *pat, int patlen,
                          long long *out_ticks, int *out_off )
{
    FB_DTPARTS pt;
    const char *p = pat, *pend = pat + patlen;
    int pos = 0;
    long long ticks;

    if( out_ticks != NULL ) *out_ticks = FB_DT_INVALID_TICKS;
    if( out_off != NULL )   *out_off = DT_PAT_OFFSET_UNSPECIFIED;
    if( s == NULL || pat == NULL || slen < 0 || patlen <= 0 )
        return 1;

    /* Constant formats.  "o"/"O" round-trips through the ISO parser; "R" and
    ** "u" are FORMAT-ONLY and are rejected here (RFC-0006 section 5). */
    if( patlen == 1 ) {
        switch( pat[0] ) {
        case 'o': case 'O':
            return fb_DtIsoParse( s, slen, out_ticks, out_off );
        case 's': pat = "yyyy-MM-dd'T'HH:mm:ss"; break;
        case 'd': pat = "yyyy-MM-dd"; break;
        case 'T': pat = "HH:mm:ss"; break;
        default:
            return 2;                   /* pattern error */
        }
        patlen = 0;
        while( pat[patlen] ) patlen++;
        p = pat;
        pend = pat + patlen;
    }

    pt.year = 1; pt.month = 1; pt.day = 1;
    pt.hour24 = 0; pt.hour12 = 0; pt.minute = 0; pt.second = 0;
    pt.sub = 0; pt.ampm = -1; pt.off = DT_PAT_OFFSET_UNSPECIFIED;
    pt.doy = 0; pt.wday = 0;
    pt.hasYear = 0; pt.hasMonth = 0; pt.hasDay = 0;
    pt.hasHour24 = 0; pt.hasHour12 = 0;
    pt.hasMin = 0; pt.hasSec = 0; pt.hasDoy = 0;

    while( p < pend ) {
        char c = *p;
        int run, v;

        if( c == '\'' ) {
            p++;
            for( ;; ) {
                if( p >= pend ) return 2;
                if( *p == '\'' ) {
                    p++;
                    if( p < pend && *p == '\'' ) {
                        if( pos >= slen || s[pos] != '\'' ) return 1;
                        pos++; p++;
                        continue;
                    }
                    break;
                }
                if( pos >= slen || s[pos] != *p ) return 1;
                pos++; p++;
            }
            continue;
        }

        if( c == '\\' ) {
            p++;
            if( p >= pend ) return 2;
            if( pos >= slen || s[pos] != *p ) return 1;
            pos++; p++;
            continue;
        }

        if( !fb_hDtPatIsAlpha( c ) ) {
            /* A literal '.' immediately followed by an F run is OPTIONAL, so
            ** that a pattern which formats away the dot also parses without
            ** it.  Keeps "HH:mm:ss.FFF" round-tripping in both directions. */
            if( c == '.' && p + 1 < pend && *( p + 1 ) == 'F' ) {
                if( pos < slen && s[pos] == '.' )
                    pos++;
                p++;
                continue;
            }
            if( pos >= slen || s[pos] != c ) return 1;
            pos++; p++;
            continue;
        }

        run = fb_hDtPatRun( p, pend );

        /* A variable-width numeric field immediately followed by another
        ** numeric field cannot be parsed unambiguously.  Fail at pattern
        ** compile time rather than on the 3rd of December. */
        if( run == 1 && fb_hDtPatTokenIsNumeric( p, pend ) &&
            c != 'f' && c != 'F' ) {
            if( fb_hDtPatTokenIsNumeric( p + run, pend ) )
                return 2;
        }

        p += run;

        switch( c ) {
        case 'y':
            if( run == 2 ) {
                /* Two-digit years are rejected on input by RFC-0005 and there
                ** is no century-inference rule here either. */
                return 2;
            }
            if( fb_hDtReadNum( s, slen, &pos, ( run >= 4 ) ? run : 0, 5, &v ) ) return 1;
            if( fb_hDtSet( &pt.year, &pt.hasYear, v ) ) return 1;
            break;
        case 'M':
            if( run <= 2 ) {
                if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
            } else if( run == 3 ) {
                if( fb_hDtMatchName( s, slen, &pos, fb_hDtMonthAbbr, 12, &v ) ) return 1;
            } else if( run == 4 ) {
                if( fb_hDtMatchName( s, slen, &pos, fb_hDtMonthFull, 12, &v ) ) return 1;
            } else return 2;
            if( fb_hDtSet( &pt.month, &pt.hasMonth, v ) ) return 1;
            break;
        case 'd':
            if( run <= 2 ) {
                if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
                if( fb_hDtSet( &pt.day, &pt.hasDay, v ) ) return 1;
            } else if( run == 3 ) {
                if( fb_hDtMatchName( s, slen, &pos, fb_hDtDayAbbr, 7, &v ) ) return 1;
                pt.wday = v;
            } else if( run == 4 ) {
                if( fb_hDtMatchName( s, slen, &pos, fb_hDtDayFull, 7, &v ) ) return 1;
                pt.wday = v;
            } else return 2;
            break;
        case 'D':
            if( fb_hDtReadNum( s, slen, &pos, ( run >= 3 ) ? 3 : 0, 3, &v ) ) return 1;
            if( fb_hDtSet( &pt.doy, &pt.hasDoy, v ) ) return 1;
            break;
        case 'H':
            if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
            if( fb_hDtSet( &pt.hour24, &pt.hasHour24, v ) ) return 1;
            break;
        case 'h':
            if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
            if( fb_hDtSet( &pt.hour12, &pt.hasHour12, v ) ) return 1;
            break;
        case 'm':
            if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
            if( fb_hDtSet( &pt.minute, &pt.hasMin, v ) ) return 1;
            break;
        case 's':
            if( fb_hDtReadNum( s, slen, &pos, ( run == 2 ) ? 2 : 0, 2, &v ) ) return 1;
            if( fb_hDtSet( &pt.second, &pt.hasSec, v ) ) return 1;
            break;
        case 'f': case 'F': {
            int i, got = 0;
            long long acc = 0;
            if( run > 7 ) return 2;
            while( got < run && pos < slen && fb_hDtPatIsDigit( s[pos] ) ) {
                acc = acc * 10 + ( s[pos] - '0' );
                pos++; got++;
            }
            /* 'f' is fixed-width and must be fully present; 'F' may be absent */
            if( c == 'f' && got != run ) return 1;
            for( i = got; i < 7; i++ )
                acc *= 10;
            pt.sub = acc;
            break;
        }
        case 't': {
            char a;
            if( pos >= slen ) return 1;
            a = s[pos];
            if( a >= 'a' && a <= 'z' ) a = (char)( a - 'a' + 'A' );
            if( a == 'A' )      pt.ampm = 0;
            else if( a == 'P' ) pt.ampm = 1;
            else return 1;
            pos++;
            if( run == 2 ) {
                char b;
                if( pos >= slen ) return 1;
                b = s[pos];
                if( b >= 'a' && b <= 'z' ) b = (char)( b - 'a' + 'A' );
                if( b != 'M' ) return 1;
                pos++;
            } else if( run > 2 ) return 2;
            break;
        }
        case 'z': case 'K': {
            int sign, hh, mm = 0;
            if( c == 'K' && run != 1 ) return 2;
            if( pos >= slen ) {
                if( c == 'K' ) break;           /* K may match nothing */
                return 1;
            }
            if( c == 'K' && ( s[pos] == 'Z' || s[pos] == 'z' ) ) {
                pos++;
                pt.off = 0;
                break;
            }
            if( s[pos] != '+' && s[pos] != '-' ) {
                if( c == 'K' ) break;
                return 1;
            }
            sign = ( s[pos] == '-' ) ? -1 : 1;
            pos++;
            if( fb_hDtReadNum( s, slen, &pos, ( run >= 2 || c == 'K' ) ? 2 : 0, 2, &hh ) ) return 1;
            if( pos < slen && s[pos] == ':' ) {
                pos++;
                if( fb_hDtReadNum( s, slen, &pos, 2, 2, &mm ) ) return 1;
            }
            if( mm > 59 ) return 1;
            pt.off = sign * ( hh * 60 + mm );
            if( pt.off < -1080 || pt.off > 1080 ) return 1;
            break;
        }
        case 'Q': case 'w': case 'Y': case 'g':
            /* Format-only: a quarter or a week number cannot reconstruct a
            ** date, and an era carries no information here.  RFC-0006 s5. */
            return 2;
        default:
            return 2;
        }
    }

    /* the input must be fully consumed */
    if( pos != slen )
        return 1;

    /* 12-hour clock plus AM/PM */
    if( pt.hasHour12 ) {
        int h;
        if( pt.hour12 < 1 || pt.hour12 > 12 ) return 1;
        h = pt.hour12 % 12;
        if( pt.ampm == 1 ) h += 12;
        if( pt.ampm == -1 && pt.hour12 == 12 ) h = 12;
        if( pt.hasHour24 && pt.hour24 != h ) return 1;
        pt.hour24 = h;
    }

    /* day-of-year, if given, decides the month and day */
    if( pt.hasDoy ) {
        int dy;
        if( pt.doy < 1 || pt.doy > fb_DtDaysInYear( pt.year ) ) return 1;
        dy = fb_DtDaysFromCivil( pt.year, 1, 1 ) + pt.doy - 1;
        {
            int yy, mm2, dd;
            fb_DtCivilFromDays( dy, &yy, &mm2, &dd );
            if( pt.hasMonth && pt.month != mm2 ) return 1;
            if( pt.hasDay && pt.day != dd ) return 1;
            pt.month = mm2;
            pt.day = dd;
        }
    }

    if( fb_DtFromCivil( pt.year, pt.month, pt.day,
                        pt.hour24, pt.minute, pt.second, pt.sub, &ticks ) )
        return 1;

    /* A named weekday in the pattern is cross-checked against the date it
    ** accompanies -- "Monday 2025-03-04" fails, because that is a Tuesday. */
    if( pt.wday != 0 ) {
        if( fb_DtDayOfWeek( fb_DtDaysFromCivil( pt.year, pt.month, pt.day ) ) != pt.wday )
            return 1;
    }

    if( out_ticks != NULL ) *out_ticks = ticks;
    if( out_off != NULL )   *out_off = pt.off;
    return 0;
}
