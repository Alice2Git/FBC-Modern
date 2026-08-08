/* chrono: modern date/time kernel.
**
** The tick model and every rule enforced here are specified in
** docs/datetime/RFC-0001-core-representation.md.  Nothing in this header
** touches, replaces or depends on the legacy fb_datetime.h surface.
**
** A tick is 100 ns.  A DateTime is a count of ticks since
** 0001-01-01T00:00:00.0000000 in the proleptic Gregorian calendar.
**
** Everything declared here is pure: no OS calls, no allocation, no locale,
** no globals, no errno.  Clocks arrive in phase 3 (RFC-0003).
*/

#ifndef __FB_CHRONO_H__
#define __FB_CHRONO_H__

/* -- units ------------------------------------------------------------- */

#define FB_DT_TICKS_PER_MICROSECOND  10LL
#define FB_DT_TICKS_PER_MILLISECOND  10000LL
#define FB_DT_TICKS_PER_SECOND       10000000LL
#define FB_DT_TICKS_PER_MINUTE       600000000LL
#define FB_DT_TICKS_PER_HOUR         36000000000LL
#define FB_DT_TICKS_PER_DAY          864000000000LL

/* -- range ------------------------------------------------------------- */

#define FB_DT_MIN_YEAR               1
#define FB_DT_MAX_YEAR               9999

#define FB_DT_MIN_DAYS               0            /* 0001-01-01 */
#define FB_DT_MAX_DAYS               3652058      /* 9999-12-31 */
#define FB_DT_DAYS_IN_RANGE          3652059

#define FB_DT_MIN_TICKS              0LL
#define FB_DT_MAX_TICKS              3155378975999999999LL

/* Absorbing sentinel.  Deliberately LLONG_MIN so that it is outside every
** valid range and so that a wrapped result can never collide with it.
** RFC-0001 section 3. */
#define FB_DT_INVALID_TICKS          (-9223372036854775807LL - 1LL)

/* -- interop epochs (RFC-0001 section 1) -------------------------------- */
/* Each is the tick count of that epoch measured from 0001-01-01, so the
** conversion is an addition.  This is why the epoch and tick size were
** chosen; see docs/datetime/rationale.md. */

#define FB_DT_DAYS_TO_UNIX_EPOCH     719162LL
#define FB_DT_TICKS_TO_UNIX_EPOCH    621355968000000000LL   /* 1970-01-01 */
#define FB_DT_TICKS_TO_FILETIME      504911232000000000LL   /* 1601-01-01 */
#define FB_DT_TICKS_TO_OLE_EPOCH     599264352000000000LL   /* 1899-12-30 */

/* -- day of week ------------------------------------------------------- */
/* ISO 8601: 1 = Monday .. 7 = Sunday.  This differs from fb_Weekday()
** (1 = Sunday) on purpose; RFC-0001 section 4 and RFC-0004 section 3. */

#define FB_DT_MONDAY     1
#define FB_DT_TUESDAY    2
#define FB_DT_WEDNESDAY  3
#define FB_DT_THURSDAY   4
#define FB_DT_FRIDAY     5
#define FB_DT_SATURDAY   6
#define FB_DT_SUNDAY     7

/* -- civil <-> ticks --------------------------------------------------- */

/* Compose ticks from civil components.  Returns 0 on success; non-zero if
** any component is out of range, in which case *out_ticks is set to
** FB_DT_INVALID_TICKS.  Does not normalize and does not clamp. */
FBCALL int       fb_DtFromCivil      ( int year, int month, int day,
                                       int hour, int minute, int second,
                                       long long subsecond_ticks,
                                       long long *out_ticks );

/* Decompose ticks into civil components.  ticks must be in
** FB_DT_MIN_TICKS .. FB_DT_MAX_TICKS. */
FBCALL void      fb_DtToCivil        ( long long ticks,
                                       int *year, int *month, int *day,
                                       int *hour, int *minute, int *second,
                                       long long *subsecond_ticks );

/* -- the two primitives everything else is built on -------------------- */
/* Closed-form days-from-civil (no table, no loop).  Exact over the whole
** range and cheap enough that the exhaustive round-trip test runs every
** build.  Input must be a valid civil date. */

FBCALL int       fb_DtDaysFromCivil  ( int year, int month, int day );
FBCALL void      fb_DtCivilFromDays  ( int days, int *year, int *month, int *day );

/* -- calendar ---------------------------------------------------------- */

FBCALL int       fb_DtIsLeapYear     ( int year );
FBCALL int       fb_DtDaysInMonth    ( int year, int month );
FBCALL int       fb_DtDaysInYear     ( int year );
FBCALL int       fb_DtDayOfWeek      ( int days );        /* 1=Mon .. 7=Sun */
FBCALL int       fb_DtDayOfYear      ( int year, int month, int day );

/* ISO 8601 week number, 1..53.  *out_iso_year receives the ISO week-year,
** which is not always `year` -- 2025-12-29 is week 1 of 2026.  Pass NULL if
** not wanted. */
FBCALL int       fb_DtIsoWeek        ( int year, int month, int day,
                                       int *out_iso_year );
FBCALL int       fb_DtIsoWeeksInYear ( int year );        /* 52 or 53 */

/* -- validation -------------------------------------------------------- */

FBCALL int       fb_DtIsValidDate    ( int year, int month, int day );
FBCALL int       fb_DtIsValidTime    ( int hour, int minute, int second,
                                       long long subsecond_ticks );
FBCALL int       fb_DtIsValidTicks   ( long long ticks );

/* -- clocks (RFC-0003) -------------------------------------------------- */
/* These are the ONLY functions here that touch the OS.  Everything above is
** pure.  Implementations: dt_clock.c (portable part) plus win32/dt_clock.c and
** unix/dt_clock.c. */

/* Wall clock, in library ticks since 0001-01-01 UTC.  Returns
** FB_DT_INVALID_TICKS if the OS clock is outside the representable range. */
FBCALL long long fb_DtClockUtcNow      ( void );

/* Granularity of the wall clock, in ticks.  Windows without
** GetSystemTimePreciseAsFileTime reports ~15.6 ms; this exists so callers can
** find out rather than guess. */
FBCALL long long fb_DtClockResolution  ( void );

/* Current local UTC offset in minutes east.  Phase 3 only answers for NOW;
** the at-an-arbitrary-instant form is RFC-0007. */
FBCALL int       fb_DtClockLocalOffsetNow( void );

/* Monotonic counter.  Raw units; divide by the frequency for seconds. */
FBCALL long long fb_DtMonoTimestamp    ( void );
FBCALL long long fb_DtMonoFrequency    ( void );
FBCALL int       fb_DtMonoIsHighRes    ( void );

/* Scale a raw monotonic count to library ticks.  Exposed because the 128-bit
** intermediate is the one place a silent wrong answer is easy to write, and
** RFC-0003 section 5 requires a pure-function test for it. */
FBCALL long long fb_DtTicksFromCounts  ( long long counts, long long freq );

/* CPU time, in ticks.  Return 0 on success.  *user and *kernel may be NULL.
** Where the split is unavailable (Linux, per-thread) *user receives the total
** and *kernel receives -1. */
FBCALL int       fb_DtCpuProcessTime   ( long long *user, long long *kernel );
FBCALL int       fb_DtCpuThreadTime    ( long long *user, long long *kernel );
FBCALL int       fb_DtCpuIsSupported   ( void );

/* -- ISO 8601 / RFC 3339 (RFC-0005) ------------------------------------ */
/* Pure, ASCII-only, locale-independent.  Format functions return the number of
** characters written and NUL-terminate; parse functions return 0 on success
** and always write the output parameters. */

FBCALL int fb_DtIsoFormat        ( long long ticks, int offMin, char *buf, int buflen );
FBCALL int fb_DtIsoFormatDate    ( int days, char *buf, int buflen );
FBCALL int fb_DtIsoFormatTime    ( long long tod, char *buf, int buflen );
FBCALL int fb_DtIsoFormatDuration( long long ticks, char *buf, int buflen );

FBCALL int fb_DtIsoParse         ( const char *s, int len, long long *out_ticks, int *out_off );
FBCALL int fb_DtIsoParseDate     ( const char *s, int len, int *out_days );
FBCALL int fb_DtIsoParseTime     ( const char *s, int len, long long *out_tod );
FBCALL int fb_DtIsoParseDuration ( const char *s, int len, long long *out_ticks );

/* -- custom patterns (RFC-0006) ---------------------------------------- */
/* Invariant English, no locale, no sprintf.  Format returns the number of
** characters written or -1 on a pattern error.  Parse returns 0 on success,
** 1 on an input mismatch, 2 on a pattern error. */

FBCALL int fb_DtPatFormat( long long ticks, int offMin,
                           const char *pat, int patlen, char *buf, int buflen );
FBCALL int fb_DtPatParse ( const char *s, int slen,
                           const char *pat, int patlen,
                           long long *out_ticks, int *out_off );

/* -- zones and locale (RFC-0007) --------------------------------------- */
/* Per-OS: win32/dt_zone.c and unix/dt_zone.c.  These touch the OS; everything
** else in this header except the clocks is pure. */

FBCALL int fb_DtZoneOffsetAt     ( long long utcTicks );   /* minutes east */
FBCALL int fb_DtZoneIsDst        ( long long utcTicks );
FBCALL int fb_DtZoneSupportsDst  ( void );
FBCALL int fb_DtZoneStandardName ( char *buf, int buflen );
FBCALL int fb_DtZoneDaylightName ( char *buf, int buflen );

/* Locale-dependent output.  CANNOT be asserted by exact string -- it is
** whatever the machine says.  RFC-0006's pattern formatter is the testable
** one, and is what should be written to a file. */
FBCALL int fb_DtLocaleDateString ( long long ticks, int style, char *buf, int buflen );
FBCALL int fb_DtLocaleTimeString ( long long ticks, int style, char *buf, int buflen );
FBCALL int fb_DtLocaleMonthName  ( int mo, int abbreviated, char *buf, int buflen );
FBCALL int fb_DtLocaleWeekdayName( int dow, int abbreviated, char *buf, int buflen );
FBCALL int fb_DtLocaleIsSupported( void );

#endif /* __FB_CHRONO_H__ */
