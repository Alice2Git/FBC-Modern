/* ustring - a portable, dynamic, UTF-16 string type
**
** WHY THIS IS NOT wstring
**
** FB's WSTRING is wchar_t-width: 2 bytes on Windows, 4 on Linux, 1 on DOS.
** The same source therefore builds a UTF-16 string on one target and a UTF-32
** string on another, and the width leaks into every byte offset, every pointer
** walk and every file written. USTRING stores uint16_t on *every* target, so
** the representation is identical everywhere and the question of platform width
** never arises.
**
** THE NO-LIBC RULE
**
** On Windows FB_UCHAR happens to be the same width as wchar_t, so wcslen(),
** wcsstr(), towlower() and friends would link and appear to work. They must
** NOT be used. Routing through libc on one target and hand-rolled code on
** another is exactly how two platforms drift apart -- which is the failure this
** type exists to remove. Every ustring primitive is hand-written in ustr_prim.c
** and behaves identically on all targets. (Precedent: DOS already does this for
** wstring under DISABLE_WCHAR, see fb_unicode.h.)
**
** ENCODING POLICY
**
** Conversion to/from the byte world (STRING, ZSTRING) is UTF-8, and malformed
** input is replaced with U+FFFD rather than raising an error -- a text editor
** must be able to open a damaged file, not refuse it. The consequence, which is
** deliberate: arbitrary *binary* does not round-trip through a USTRING. Binary
** belongs in STRING, which is unchanged.
**
** LENGTH IS AUTHORITATIVE, NOT THE TERMINATOR
**
** The buffer is NUL-terminated as a courtesy for C interop, but every operation
** uses the stored length, so embedded NULs survive: "AB" + NUL + "CD" is five
** code units and stays five.
*/

#ifndef __FB_USTRING_H__
#define __FB_USTRING_H__

/* A UTF-16 code unit. uint16_t on every target fbc supports -- never wchar_t. */
typedef uint16_t FB_UCHAR;

/* Substituted for every malformed sequence and every lone surrogate. */
#define FB_UCHAR_REPLACEMENT ((FB_UCHAR)0xFFFD)

/* Surrogate arithmetic. Written once, here, so no caller hand-rolls it. */
#define FB_UCHAR_IS_HIGHSUR(u) (((u) & 0xFC00) == 0xD800)
#define FB_UCHAR_IS_LOWSUR(u)  (((u) & 0xFC00) == 0xDC00)
#define FB_UCHAR_IS_SUR(u)     (((u) & 0xF800) == 0xD800)
#define FB_UCHAR_SURPAIR_CP(hi,lo) \
    ( 0x10000u + ((((uint32_t)(hi) - 0xD800u) << 10) | ((uint32_t)(lo) - 0xDC00u)) )
#define FB_UCHAR_CP_HIGHSUR(cp) ((FB_UCHAR)(0xD800u + (((uint32_t)(cp) - 0x10000u) >> 10)))
#define FB_UCHAR_CP_LOWSUR(cp)  ((FB_UCHAR)(0xDC00u + (((uint32_t)(cp) - 0x10000u) & 0x3FFu)))

#define FB_UCHAR_MAX_CP 0x10FFFFu

/** Flag identifying a ustring size as variable length.
 *
 * The size argument threaded through every entry point discriminates the three
 * forms a ustring argument can take. This mirrors FB_STRSIZEVARLEN /
 * FB_STRISFIXED in fb_string.h exactly, and reuses those bit masks:
 *
 *   -1                    var-len USTRING, ptr is an FBUSTRING descriptor
 *   size & FB_STRISFIXED  fix-len USTRING*N, N code units, ptr is raw units
 *   0                     raw FB_UCHAR *, length unknown, walk to the NUL
 */
#define FB_USTRSIZEVARLEN -1

/** Structure containing information about a specific ustring.
 *
 * NOTE: len and size are both in CODE UNITS, never bytes. FBSTRING gets away
 * with byte == char; here they differ by sizeof(FB_UCHAR), so mixing the two is
 * the likeliest source of silent corruption. The multiply appears in exactly one
 * place -- the allocator in ustr_core.c.
 */
typedef struct _FBUSTRING {
    FB_UCHAR       *data;    /**< pointer to the real string data */
    ssize_t         len;     /**< String length, in code units. */
    ssize_t         size;    /**< Allocated code units, excluding the terminator. */
} FBUSTRING;

typedef struct _FB_USTR_TMPDESC {
    FB_LISTELEM     elem;
    FBUSTRING       desc;
} FB_USTR_TMPDESC;

/* Two invariants the whole design rests on, checked at compile time on every
 * target rather than assumed:
 *
 *  1. a code unit is exactly 2 bytes EVERYWHERE -- that is the entire point of
 *     the type, and a target where it is not would silently produce a different
 *     representation, which is the bug ustring exists to prevent;
 *  2. the descriptor is exactly pointer + 2 ssize_t with no padding, because
 *     fbc hardcodes its size (12 on 32-bit / 24 on 64-bit) in symb-data.bas and
 *     the two must agree or every ustring variable is the wrong size on the stack.
 *
 * A negative array bound is used rather than static_assert / _Static_assert:
 * the rtlib is built as C89 on some targets. */
typedef char __fb_ustring_uchar_is_2_bytes
    [ (sizeof(FB_UCHAR) == 2) ? 1 : -1 ];
typedef char __fb_ustring_desc_has_no_padding
    [ (sizeof(FBUSTRING) == sizeof(void *) + 2 * sizeof(ssize_t)) ? 1 : -1 ];

/** Returns if the ustring is a temporary ustring.
 *
 * The temp flag lives in the sign bit of ->len (the same FB_TEMPSTRBIT the
 * narrow side uses), so ->len must never be read raw -- always FB_USTRSIZE().
 */
#define FB_UISTEMP(s) ((((FBUSTRING *)s)->len & FB_TEMPSTRBIT) != 0)

/** Returns a ustring length in code units.
 */
#define FB_USTRSIZE(s) ((ssize_t)(((FBUSTRING *)s)->len & ~FB_TEMPSTRBIT))

/** Decode a (ptr,size) pair into a data pointer and a length in code units.
 */
#define FB_USTRSETUP(s,size,ptr,len)                        \
do {                                                        \
    if( s == NULL )                                         \
    {                                                       \
        ptr = NULL;                                         \
        len = 0;                                            \
    }                                                       \
    else                                                    \
    {                                                       \
        if( size == FB_USTRSIZEVARLEN )                     \
        {                                                   \
            /* var-len USTRING, descriptor */               \
            ptr = ((FBUSTRING *)s)->data;                   \
            len = FB_USTRSIZE( s );                         \
        }                                                   \
        else if( size & FB_STRISFIXED )                     \
        {                                                   \
            /* fix-len USTRING*N.                           \
             * The length is walked, NOT taken from the size:\
             * the size carries the CAPACITY, and reading    \
             * must yield the actual text length. USTRING*N  \
             * is NUL-terminated and follows WSTRING*N here, \
             * not STRING*N (which space-pads, so its LEN    \
             * really is its capacity).                      \
             * Writers take the capacity from the size       \
             * argument directly and so are unaffected. */   \
            ptr = (FB_UCHAR *)s;                            \
            len = fb_hUStrLen( (FB_UCHAR *)s );             \
        }                                                   \
        else                                                \
        {                                                   \
            /* raw FB_UCHAR *, unknown length */            \
            ptr = (FB_UCHAR *)s;                            \
            len = fb_hUStrLen( (FB_UCHAR *)s );             \
        }                                                   \
    }                                                       \
} while (0)

/** Sets the length of a ustring (without reallocation).
 *
 * Preserves the temp flag.
 */
static __inline__ void fb_hUStrSetLength( FBUSTRING *str, size_t units ) {
    str->len = units | (str->len & FB_TEMPSTRBIT);
}


/* ---------------------------------------------------------------- ustr_prim.c
** Hand-rolled primitives. No libc wide function is used by any of these -- see
** the no-libc rule at the top of this file.
*/
ssize_t             fb_hUStrLen             ( const FB_UCHAR *s );
int                 fb_hUStrCompare         ( const FB_UCHAR *s1, ssize_t len1,
                                              const FB_UCHAR *s2, ssize_t len2 );
void                fb_hUStrCopy            ( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units );
void                fb_hUStrCopyN           ( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units );
void                fb_hUStrMove            ( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units );
void                fb_hUStrFill            ( FB_UCHAR *dst, FB_UCHAR c, ssize_t units );
ssize_t             fb_hUStrChr             ( const FB_UCHAR *s, ssize_t len, FB_UCHAR c );
ssize_t             fb_hUStrStr             ( const FB_UCHAR *hay, ssize_t haylen,
                                              const FB_UCHAR *needle, ssize_t needlelen );
const FB_UCHAR     *fb_hUStrSkipChar        ( const FB_UCHAR *s, ssize_t len, FB_UCHAR c );
const FB_UCHAR     *fb_hUStrSkipCharRev     ( const FB_UCHAR *s, ssize_t len, FB_UCHAR c );


/* ---------------------------------------------------------------- ustr_utf.c
** Codecs. Hand-rolled rather than reusing utf_conv*.c, which is wchar_t-shaped,
** mostly static, little-endian-only and has no replacement-character policy.
**
** Every converter writes at most dst_units/dst_bytes and returns the count it
** WOULD have written (snprintf semantics), so a caller may pass dst == NULL to
** measure exactly. In practice callers size with the _MAX macros below and get
** the exact length back in one pass.
*/

/* Upper bounds, so one pass suffices.
   UTF-8 -> UTF-16: 1..3 source bytes yield 1 unit, 4 yield 2, an invalid byte
   yields 1; so units <= bytes, always.
   UTF-16 -> UTF-8: a BMP unit yields at most 3 bytes; a surrogate pair is 2
   units yielding 4 bytes (<= 6); a lone surrogate is 1 unit yielding 3. */
#define FB_UTF8_TO_UTF16_MAX(bytes) (bytes)
#define FB_UTF16_TO_UTF8_MAX(units) ((units) * 3)
#define FB_UTF32_TO_UTF16_MAX(units) ((units) * 2)
#define FB_UTF16_TO_UTF32_MAX(units) (units)

ssize_t             fb_hUtf8ToUtf16         ( const char *src, ssize_t src_bytes,
                                              FB_UCHAR *dst, ssize_t dst_units );
ssize_t             fb_hUtf16ToUtf8         ( const FB_UCHAR *src, ssize_t src_units,
                                              char *dst, ssize_t dst_bytes );
ssize_t             fb_hUtf32ToUtf16        ( const uint32_t *src, ssize_t src_units,
                                              FB_UCHAR *dst, ssize_t dst_units );
ssize_t             fb_hUtf16ToUtf32        ( const FB_UCHAR *src, ssize_t src_units,
                                              uint32_t *dst, ssize_t dst_units );

/* Decode the codepoint starting at src[i]. Returns the codepoint and, via
   *units_used, how many code units it occupied (1 or 2). A lone surrogate
   yields U+FFFD and consumes 1. */
uint32_t            fb_hUStrCodepointAt     ( const FB_UCHAR *src, ssize_t len,
                                              ssize_t i, ssize_t *units_used );


/* ---------------------------------------------------------------- ustr_core.c
** Descriptor and temp-descriptor management. Direct port of str_core.c; the
** allocation policy (round to 32 units, grow by 12.5%) is deliberately the same,
** so that repeated appends stay amortised O(1).
*/
FBCALL FBUSTRING   *fb_hUStrAllocTempDesc   ( void );
FBCALL int          fb_hUStrDelTempDesc     ( FBUSTRING *str );
FBCALL FBUSTRING   *fb_hUStrAlloc           ( FBUSTRING *str, ssize_t units );
FBCALL FBUSTRING   *fb_hUStrRealloc         ( FBUSTRING *str, ssize_t units, int preserve );
FBCALL FBUSTRING   *fb_hUStrAllocTemp       ( FBUSTRING *str, ssize_t units );
FBCALL FBUSTRING   *fb_hUStrAllocTemp_NoLock( FBUSTRING *str, ssize_t units );
FBCALL int          fb_hUStrDelTemp         ( FBUSTRING *str );
FBCALL int          fb_hUStrDelTemp_NoLock  ( FBUSTRING *str );

FBCALL void         fb_UStrDelete           ( FBUSTRING *str );


/* ------------------------------------------------------- public ustring API
** Every entry point takes (ptr, size) pairs, where size is the discriminator
** documented at FB_USTRSIZEVARLEN above. One entry point therefore serves the
** var-len, fixed-len and raw-pointer forms, and the compiler emits the same
** call regardless of which it has.
*/
FBCALL void        *fb_UStrInit         ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem );
FBCALL void        *fb_UStrAssign       ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem );
FBCALL void        *fb_UStrAssignEx     ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem, int is_init );
FBCALL FBUSTRING   *fb_UStrConcat       ( FBUSTRING *dst, void *str1, ssize_t str1_size, void *str2, ssize_t str2_size );
FBCALL void        *fb_UStrConcatAssign ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem );
FBCALL int          fb_UStrCompare      ( void *str1, ssize_t str1_size, void *str2, ssize_t str2_size );
FBCALL ssize_t      fb_UStrLen          ( void *str, ssize_t str_size );


/* ------------------------------------------- narrow <-> ustring conversion
** UTF-8 in both directions, on every target, with U+FFFD for malformed input.
** NOT the locale-based path STRING <-> WSTRING uses -- that is codepage- and
** platform-dependent, which a portable type cannot afford.
*/
FBCALL void        *fb_UStrAssignFromA   ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem, int is_init );
FBCALL void        *fb_UStrAssignToA     ( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int fill_rem, int is_init );
FBCALL FBUSTRING   *fb_StrToUStr         ( void *src, ssize_t src_size );
FBCALL FBSTRING    *fb_UStrToStr         ( void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrConcatAU      ( FBUSTRING *dst, void *str1, ssize_t str1_size, void *str2, ssize_t str2_size );
FBCALL FBUSTRING   *fb_UStrConcatUA      ( FBUSTRING *dst, void *str1, ssize_t str1_size, void *str2, ssize_t str2_size );
FBCALL FBUSTRING   *fb_UStrAllocTempResult( FBUSTRING *src );

/* -------------------------------------------- wstring <-> ustring conversion
 * FB_WCHAR is wchar_t, so this is a no-op copy on Windows (both UTF-16) and a
 * real re-encoding on Linux (UTF-32). See ustr_convw.c.
 */
FBCALL void        *fb_UStrAssignFromW   ( void *dst, ssize_t dst_size, const FB_WCHAR *src, int fill_rem, int is_init );
FBCALL FB_WCHAR    *fb_UStrAssignToW     ( FB_WCHAR *dst, ssize_t dst_chars, void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_WstrToUStr        ( const FB_WCHAR *src );
FBCALL FB_WCHAR    *fb_UStrToWstr        ( void *src, ssize_t src_size );


/* ------------------------------------------------------------- intrinsics
 * Positions and lengths are CODE UNITS and 1-based, matching LEN() and []
 * indexing. Searching by code unit is safe for UTF-16 without surrogate
 * awareness: a surrogate half can never equal a BMP unit, so a match cannot
 * land mid-character.
 */
FBCALL FBUSTRING   *fb_UStrLeft          ( void *src, ssize_t src_size, ssize_t units );
FBCALL FBUSTRING   *fb_UStrRight         ( void *src, ssize_t src_size, ssize_t units );
/* two-parameter forms, for the LEFT/RIGHT overload entries */
FBCALL FBUSTRING   *fb_UStrLeftD         ( FBUSTRING *src, ssize_t units );
FBCALL FBUSTRING   *fb_UStrRightD        ( FBUSTRING *src, ssize_t units );
FBCALL FBUSTRING   *fb_UStrMid           ( void *src, ssize_t src_size, ssize_t start, ssize_t units );
FBCALL void         fb_UStrAssignMid     ( void *dst, ssize_t dst_size, ssize_t start, ssize_t units, void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrSpace         ( ssize_t units );
FBCALL FBUSTRING   *fb_UStrFill1         ( ssize_t units, int unit );
FBCALL FBUSTRING   *fb_UStrFill2         ( ssize_t units, void *src, ssize_t src_size );

FBCALL FBUSTRING   *fb_UStrTrim          ( void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrLTrim         ( void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrRTrim         ( void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrTrimEx        ( void *src, ssize_t src_size, void *pat, ssize_t pat_size );
FBCALL FBUSTRING   *fb_UStrLTrimEx       ( void *src, ssize_t src_size, void *pat, ssize_t pat_size );
FBCALL FBUSTRING   *fb_UStrRTrimEx       ( void *src, ssize_t src_size, void *pat, ssize_t pat_size );
FBCALL FBUSTRING   *fb_UStrTrimAny       ( void *src, ssize_t src_size, void *set, ssize_t set_size );
FBCALL FBUSTRING   *fb_UStrLTrimAny      ( void *src, ssize_t src_size, void *set, ssize_t set_size );
FBCALL FBUSTRING   *fb_UStrRTrimAny      ( void *src, ssize_t src_size, void *set, ssize_t set_size );

FBCALL ssize_t      fb_UStrInstr         ( ssize_t start, void *src, ssize_t src_size, void *pat, ssize_t pat_size );
FBCALL ssize_t      fb_UStrInstrAny      ( ssize_t start, void *src, ssize_t src_size, void *set, ssize_t set_size );
FBCALL ssize_t      fb_UStrInstrRev      ( void *src, ssize_t src_size, void *pat, ssize_t pat_size, ssize_t start );
FBCALL ssize_t      fb_UStrInstrRevAny   ( void *src, ssize_t src_size, void *set, ssize_t set_size, ssize_t start );

/* Simple case mapping, from the generated table in ustr_casetable.c.
 * NOT towupper()/towlower(), which are locale-dependent. */
FB_UCHAR            fb_hUStrToUpper      ( FB_UCHAR c );
FB_UCHAR            fb_hUStrToLower      ( FB_UCHAR c );
FBCALL FBUSTRING   *fb_UStrUcase         ( void *src, ssize_t src_size );
FBCALL FBUSTRING   *fb_UStrLcase         ( void *src, ssize_t src_size );

FBCALL int          fb_UStrAsc           ( void *src, ssize_t src_size, ssize_t pos );
FBCALL void         fb_UStrLset          ( void *dst, ssize_t dst_size, void *src, ssize_t src_size );
FBCALL void         fb_UStrRset          ( void *dst, ssize_t dst_size, void *src, ssize_t src_size );
FBCALL void         fb_UStrSwap          ( void *str1, ssize_t size1, void *str2, ssize_t size2 );

/* PRINT / WRITE. The encoding depends on where the output goes -- see
 * ustr_print.c: a real Windows console takes the wide path, everything else
 * (files, redirected output, non-Windows consoles) gets UTF-8. */
FBCALL void         fb_PrintUStr         ( int fnum, FBUSTRING *src, int mask );
FBCALL void         fb_WriteUStr         ( int fnum, FBUSTRING *src, int mask );

/* PRINT USING. Lives in io_printusg.c, beside the narrow and wide versions,
 * because it needs that file's format-string context. Field widths count CODE
 * UNITS -- see the note there for why it cannot just convert and delegate. */
FBCALL int          fb_PrintUsingUStr    ( int fnum, FBUSTRING *src, int mask );

/* LINE INPUT # and INPUT #. In ustr_fileio.c, because ENCODING is a RUNTIME
 * property of the file: a plain file is UTF-8 bytes, an ENCODING file is
 * already decoded by the device, and the compiler cannot tell which. */
FBCALL int          fb_FileLineInputUStr ( int fnum, FBUSTRING *dst );
FBCALL int          fb_InputUStr         ( FBUSTRING *dst );

#endif /*__FB_USTRING_H__*/
