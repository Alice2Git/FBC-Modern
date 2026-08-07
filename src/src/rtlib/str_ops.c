/* FB.* string algorithms, BYTE width -- the STRING and ZSTRING entry points.
**
** The algorithms are in str_ops_core.h; this file supplies the byte
** instantiation and the FBCALL wrappers around it.
**
** ARGUMENTS ARE DESCRIPTORS, ALWAYS.
**
** These are reached from FreeBASIC through a plain
**
**     extern "C" declare function ... alias "fb_StrTally" _
**         ( byref s as const string, ... ) as long
**
** and NOT through the compiler's intrinsic path, so there is no
** (void *ptr, ssize_t size) discriminator to unpack. A `byref as const string`
** parameter carries an FBSTRING descriptor for every argument form -- measured,
** not assumed: a literal, a var-len STRING, a STRING * N, a ZSTRING * N and a
** concatenation temporary all arrive as descriptors. A NULL descriptor and a
** descriptor with a NULL data pointer both mean the empty string.
**
** ZSTRING is served by this same entry point, through fbc's own implicit
** conversion. That conversion is bytes to bytes with no locale involved, so it
** is exact; it does cost a temporary, which is the price of not having a fourth
** overload. (A `byref as const zstring` overload was measured and rejected: it
** silently captures STRING and USTRING arguments too, binding them to the wrong
** implementation rather than reporting an ambiguity.)
**
** THE PATTERN ARGUMENT IS A USTRING, EVEN HERE.
**
** fbc resolves an overload on ALL of its parameters, so a set overloaded on the
** first one can only be disambiguated if every LATER parameter has a single type
** shared by all three overloads -- measured: with mixed types on the second
** parameter, `Tally( someWstring, "abc" )` is an ambiguity error rather than a
** choice. USTRING is that shared type, so a byte-family pattern arrives as UTF-16
** and is encoded back to bytes here.
**
** For an ASCII or UTF-8 pattern that round trip is exact, and for a LITERAL it
** costs nothing at run time -- fbc converts string literals to ustring at
** compile time. What it does not survive is a pattern of arbitrary non-UTF-8
** bytes, which is the boundary USTRING already documents: binary belongs in
** STRING and is not searchable by a ustring-typed pattern. Stated in
** inc/fb/string.bi where callers will see it.
**
** CASE FOLDING IS ASCII ONLY.
**
** A STRING is a byte buffer with no declared encoding -- it may be UTF-8,
** CP-1252, or binary. Folding anything above 127 would be guessing at a
** codepage, and would make the same program fold differently on two machines.
** So A-Z only. Callers who need Unicode case rules have USTRING, whose fold is
** a generated table and is identical everywhere.
*/

#include "fb.h"

/* --- the byte instantiation of str_ops_core.h --- */

#define FB_SOP_UNIT      char
#define FB_SOP_UUNIT     unsigned char
#define FB_SOP(name)     hb_##name

/* ASCII fold, deliberately. See the header comment. */
#define FB_SOP_FOLD(c)   ( (unsigned char)( ((c) >= 'a' && (c) <= 'z') ? ((c) - 32) : (c) ) )
#define FB_SOP_UPPER(c)  FB_SOP_FOLD(c)
#define FB_SOP_LOWER(c)  ( (unsigned char)( ((c) >= 'A' && (c) <= 'Z') ? ((c) + 32) : (c) ) )

/* A word character, for title case. ASCII alphanumerics, plus everything at or
** above 0x80 -- in a UTF-8 STRING those are the continuation and lead bytes of
** a letter, so treating them as word characters keeps a multi-byte letter from
** being read as a word boundary. */
#define FB_SOP_ISWORD(c) ( ((c) >= '0' && (c) <= '9') ||                            ((c) >= 'A' && (c) <= 'Z') ||                            ((c) >= 'a' && (c) <= 'z') || ((c) >= 0x80) )

/* No surrogates at byte width: both fold to 0 and the pair branch in
** hReverseFill disappears entirely. */
#define FB_SOP_ISHIGH(c) 0
#define FB_SOP_ISLOW(c)  0

#include "str_ops_core.h"

#undef FB_SOP_UNIT
#undef FB_SOP_UUNIT
#undef FB_SOP
#undef FB_SOP_FOLD
#undef FB_SOP_UPPER
#undef FB_SOP_LOWER
#undef FB_SOP_ISWORD
#undef FB_SOP_ISHIGH
#undef FB_SOP_ISLOW

/* --- descriptor unpacking --- */

/* A NULL descriptor, or one with no data, is the empty string. */
static void hStrArg( FBSTRING *s, const char **ptr, ssize_t *len )
{
	if( s == NULL || s->data == NULL )
	{
		*ptr = "";
		*len = 0;
	}
	else
	{
		*ptr = s->data;
		*len = s->len;
	}
}

/* --- the ustring pattern, encoded down to bytes ---
**
** Deliberately NOT fb_UStrToStr(): that allocates a temp descriptor and takes
** the string lock, and a pattern is nearly always a handful of ASCII characters.
** fb_hUtf16ToUtf8() measures first, so a short pattern encodes into the stack
** and never allocates at all; only a long one reaches malloc. */

#define HPAT_STACK 128

typedef struct {
	const char *ptr;
	ssize_t     len;
	char       *heap;               /* non-NULL only when the stack buffer was too small */
	char        buf[HPAT_STACK];
} HPAT;

static void hPatArg( FBUSTRING *pat, HPAT *p )
{
	const FB_UCHAR *up;
	ssize_t ulen, nbytes;

	p->heap = NULL;
	p->ptr  = "";
	p->len  = 0;

	if( pat == NULL || pat->data == NULL || pat->len <= 0 )
		return;

	up   = pat->data;
	ulen = pat->len;

	nbytes = fb_hUtf16ToUtf8( up, ulen, NULL, 0 );
	if( nbytes <= 0 )
		return;

	if( nbytes < (ssize_t)sizeof( p->buf ) )
	{
		fb_hUtf16ToUtf8( up, ulen, p->buf, nbytes );
		p->ptr = p->buf;
		p->len = nbytes;
	}
	else
	{
		p->heap = (char *)malloc( nbytes + 1 );
		if( p->heap == NULL )
			return;                 /* out of memory: behave as the empty pattern */

		fb_hUtf16ToUtf8( up, ulen, p->heap, nbytes );
		p->ptr = p->heap;
		p->len = nbytes;
	}
}

static void hPatRel( HPAT *p )
{
	if( p->heap != NULL )
	{
		free( p->heap );
		p->heap = NULL;
	}
}

/* --- search and inspect ---
**
** Every position argument and every position result is 1-BASED, and 0 means
** "not found", matching INSTR. The conversion happens here and nowhere else. */

/* FB.Tally( s, match [, ignoreCase] ) -- non-overlapping occurrences */
FBCALL ssize_t fb_StrTally( FBSTRING *s, FBUSTRING *pat, int ic )
{
	const char *sp;
	ssize_t sl, r;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );

	r = hb_hTally( sp, sl, p.ptr, p.len, ic );

	hPatRel( &p );
	return r;
}

/* FB.TallyChars( s, chars [, ignoreCase] ) -- bytes of s that are in the set */
FBCALL ssize_t fb_StrTallyChars( FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, r;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	r = hb_hTallyAny( sp, sl, p.ptr, p.len, ic );

	hPatRel( &p );
	return r;
}

/* FB.InstrChars( start, s, chars [, ignoreCase] ) -- first position in the set */
FBCALL ssize_t fb_StrInstrChars( ssize_t start, FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, at, r;
	HPAT p;

	if( start < 1 )
		return 0;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	at = hb_hFindAny( sp, sl, p.ptr, p.len, start - 1, ic );
	r = (at < 0) ? 0 : at + 1;

	hPatRel( &p );
	return r;
}

/* FB.VerifySet( start, s, chars [, ignoreCase] ) -- first position NOT in the set */
FBCALL ssize_t fb_StrVerifySet( ssize_t start, FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, at, r;
	HPAT p;

	if( start < 1 )
		return 0;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	at = hb_hVerify( sp, sl, p.ptr, p.len, start - 1, ic );
	r = (at < 0) ? 0 : at + 1;

	hPatRel( &p );
	return r;
}

/* FB.SpanOf( start, s, chars [, ignoreCase] ) -- run length of set members */
FBCALL ssize_t fb_StrSpanOf( ssize_t start, FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, r;
	HPAT p;

	if( start < 1 )
		return 0;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	r = hb_hSpan( sp, sl, p.ptr, p.len, start - 1, ic );

	hPatRel( &p );
	return r;
}

/* FB.StartsWith / FB.EndsWith / FB.Contains -- an empty affix is present in
** every string, the empty one included. */
FBCALL int fb_StrStartsWith( FBSTRING *s, FBUSTRING *pre, int ic )
{
	const char *sp;
	ssize_t sl;
	int r;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( pre, &p );

	r = hb_hStartsWith( sp, sl, p.ptr, p.len, ic );

	hPatRel( &p );
	return r;
}

FBCALL int fb_StrEndsWith( FBSTRING *s, FBUSTRING *suf, int ic )
{
	const char *sp;
	ssize_t sl;
	int r;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( suf, &p );

	r = hb_hEndsWith( sp, sl, p.ptr, p.len, ic );

	hPatRel( &p );
	return r;
}

FBCALL int fb_StrContains( FBSTRING *s, FBUSTRING *pat, int ic )
{
	const char *sp;
	ssize_t sl;
	int r;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );

	/* consistent with StartsWith rather than with hFind: every string
	** contains the empty string */
	r = (p.len <= 0) ? 1 : (hb_hFind( sp, sl, p.ptr, p.len, 0, ic ) >= 0);

	hPatRel( &p );
	return r;
}

/* --- extract family, byte width ---
**
** These RETURN TEXT, so each hands back a temp FBSTRING that the CALLER frees.
** That is fbc's ordinary handling for a `as string` result reached through a
** plain declare -- the same contract fb_StrFormat has -- and it is why nothing
** here releases its own arguments: they are the caller's, not ours.
**
** A ZSTRING argument therefore also comes back as a STRING. There is no dynamic
** ZSTRING to return. */

/* Allocate a temp and fill it from src[0..n-1]. n <= 0 yields the null desc,
** which is the empty string and must NOT be freed by anyone. */
static FBSTRING *hStrTempFrom( const char *src, ssize_t n )
{
	FBSTRING *dst;

	if( n <= 0 )
		return &__fb_ctx.null_desc;

	dst = fb_hStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.null_desc;

	if( dst->data != NULL )
	{
		fb_hStrCopy( dst->data, src, n );
		dst->data[n] = 0;
	}

	return dst;
}

/* Two runs of the source joined, for DeleteAt. */
static FBSTRING *hStrTempFrom2
	(
		const char *a, ssize_t alen, const char *b, ssize_t blen
	)
{
	FBSTRING *dst;
	ssize_t n = alen + blen;

	if( n <= 0 )
		return &__fb_ctx.null_desc;

	dst = fb_hStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.null_desc;

	if( dst->data != NULL )
	{
		if( alen > 0 )
			fb_hStrCopy( dst->data, a, alen );
		if( blen > 0 )
			fb_hStrCopy( dst->data + alen, b, blen );
		dst->data[n] = 0;
	}

	return dst;
}

FBCALL FBSTRING *fb_StrExtract( ssize_t start, FBSTRING *s, FBUSTRING *pat, int ic )
{
	const char *sp;
	ssize_t sl, off, cnt;
	FBSTRING *r;
	HPAT p;

	if( start < 1 )
		return &__fb_ctx.null_desc;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );

	hb_hExtractSpan( sp, sl, p.ptr, p.len, start - 1, ic, &off, &cnt );
	r = hStrTempFrom( sp + off, cnt );

	hPatRel( &p );
	return r;
}

FBCALL FBSTRING *fb_StrExtractChars( ssize_t start, FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, off, cnt;
	FBSTRING *r;
	HPAT p;

	if( start < 1 )
		return &__fb_ctx.null_desc;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	hb_hExtractCharsSpan( sp, sl, p.ptr, p.len, start - 1, ic, &off, &cnt );
	r = hStrTempFrom( sp + off, cnt );

	hPatRel( &p );
	return r;
}

FBCALL FBSTRING *fb_StrRemain( FBSTRING *s, FBUSTRING *pat, ssize_t start, int ic )
{
	const char *sp;
	ssize_t sl, off, cnt;
	FBSTRING *r;
	HPAT p;

	if( start < 1 )
		return &__fb_ctx.null_desc;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );

	hb_hRemainSpan( sp, sl, p.ptr, p.len, start - 1, ic, &off, &cnt );
	r = hStrTempFrom( sp + off, cnt );

	hPatRel( &p );
	return r;
}

FBCALL FBSTRING *fb_StrRemainChars( FBSTRING *s, FBUSTRING *set, ssize_t start, int ic )
{
	const char *sp;
	ssize_t sl, off, cnt;
	FBSTRING *r;
	HPAT p;

	if( start < 1 )
		return &__fb_ctx.null_desc;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	hb_hRemainCharsSpan( sp, sl, p.ptr, p.len, start - 1, ic, &off, &cnt );
	r = hStrTempFrom( sp + off, cnt );

	hPatRel( &p );
	return r;
}

FBCALL FBSTRING *fb_StrBetween
	(
		FBSTRING *s, FBUSTRING *d1, FBUSTRING *d2, ssize_t start, int ic
	)
{
	const char *sp;
	ssize_t sl, off, cnt;
	FBSTRING *r;
	HPAT p1, p2;

	if( start < 1 )
		return &__fb_ctx.null_desc;

	hStrArg( s, &sp, &sl );
	hPatArg( d1, &p1 );
	hPatArg( d2, &p2 );

	hb_hBetweenSpan( sp, sl, p1.ptr, p1.len, p2.ptr, p2.len, start - 1, ic, &off, &cnt );
	r = hStrTempFrom( sp + off, cnt );

	hPatRel( &p1 );
	hPatRel( &p2 );
	return r;
}

FBCALL FBSTRING *fb_StrClipLeft( FBSTRING *s, ssize_t n )
{
	const char *sp;
	ssize_t sl, off, cnt;

	hStrArg( s, &sp, &sl );
	hb_hClipLeftSpan( sl, n, &off, &cnt );

	return hStrTempFrom( sp + off, cnt );
}

FBCALL FBSTRING *fb_StrClipRight( FBSTRING *s, ssize_t n )
{
	const char *sp;
	ssize_t sl, off, cnt;

	hStrArg( s, &sp, &sl );
	hb_hClipRightSpan( sl, n, &off, &cnt );

	return hStrTempFrom( sp + off, cnt );
}

FBCALL FBSTRING *fb_StrDeleteAt( FBSTRING *s, ssize_t start, ssize_t count )
{
	const char *sp;
	ssize_t sl, coff, clen;

	hStrArg( s, &sp, &sl );
	hb_hDeleteCut( sl, start, count, &coff, &clen );

	if( clen <= 0 )
		return hStrTempFrom( sp, sl );          /* nothing removed */

	return hStrTempFrom2( sp, coff, sp + coff + clen, sl - coff - clen );
}

FBCALL FBSTRING *fb_StrInsertAt( FBSTRING *s, FBUSTRING *ins, ssize_t pos )
{
	const char *sp;
	ssize_t sl, at, n;
	FBSTRING *dst;
	HPAT p;

	hStrArg( s, &sp, &sl );

	at = hb_hInsertSplit( sl, pos );
	if( at < 0 )
		return hStrTempFrom( sp, sl );          /* position below 1: untouched */

	hPatArg( ins, &p );

	n = sl + p.len;
	if( n <= 0 )
	{
		hPatRel( &p );
		return &__fb_ctx.null_desc;
	}

	dst = fb_hStrAllocTemp( NULL, n );
	if( dst == NULL )
	{
		hPatRel( &p );
		return &__fb_ctx.null_desc;
	}

	if( dst->data != NULL )
	{
		if( at > 0 )
			fb_hStrCopy( dst->data, sp, at );
		if( p.len > 0 )
			fb_hStrCopy( dst->data + at, p.ptr, p.len );
		if( sl - at > 0 )
			fb_hStrCopy( dst->data + at + p.len, sp + at, sl - at );
		dst->data[n] = 0;
	}

	hPatRel( &p );
	return dst;
}

/* --- transform family, byte width ---
**
** Each builds a new string whose length is known before it is written, so there
** is no measure pass: the caller-side allocation below is exact, or a safe
** upper bound where the result can only shrink. */

/* Allocate a temp of exactly n and hand back its buffer, or NULL. */
static FBSTRING *hStrTempAlloc( ssize_t n, char **out )
{
	FBSTRING *dst;

	*out = NULL;

	if( n <= 0 )
		return &__fb_ctx.null_desc;

	dst = fb_hStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.null_desc;

	*out = dst->data;
	return dst;
}

/* Trim a temp whose fill wrote fewer units than were reserved. The descriptor
** owns the block either way, so this only corrects the length. */
static void hStrTempTrim( FBSTRING *dst, ssize_t written )
{
	if( dst->data == NULL )
		return;

	fb_hStrSetLength( dst, written );
	dst->data[written] = 0;
}

FBCALL FBSTRING *fb_StrReplace( FBSTRING *s, FBUSTRING *pat, FBUSTRING *rep, int ic )
{
	const char *sp;
	ssize_t sl, n, count, w;
	FBSTRING *dst;
	char *out;
	HPAT p, r;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );
	hPatArg( rep, &r );

	/* hTally walks with the same loop hReplaceFill does, so the size is
	   exact rather than an estimate */
	count = hb_hTally( sp, sl, p.ptr, p.len, ic );
	n = sl + count * (r.len - p.len);

	dst = hStrTempAlloc( n, &out );
	if( out != NULL )
	{
		w = hb_hReplaceFill( out, sp, sl, p.ptr, p.len, r.ptr, r.len, ic );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p );
	hPatRel( &r );
	return dst;
}

FBCALL FBSTRING *fb_StrRemove( FBSTRING *s, FBUSTRING *pat, int ic )
{
	const char *sp;
	ssize_t sl, n, count, w;
	FBSTRING *dst;
	char *out;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( pat, &p );

	count = hb_hTally( sp, sl, p.ptr, p.len, ic );
	n = sl - count * p.len;

	dst = hStrTempAlloc( n, &out );
	if( out != NULL )
	{
		w = hb_hReplaceFill( out, sp, sl, p.ptr, p.len, NULL, 0, ic );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p );
	return dst;
}

FBCALL FBSTRING *fb_StrRemoveChars( FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, w;
	FBSTRING *dst;
	char *out;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		w = hb_hRemoveCharsFill( out, sp, sl, p.ptr, p.len, ic );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p );
	return dst;
}

FBCALL FBSTRING *fb_StrRetainChars( FBSTRING *s, FBUSTRING *set, int ic )
{
	const char *sp;
	ssize_t sl, w;
	FBSTRING *dst;
	char *out;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		w = hb_hRetainCharsFill( out, sp, sl, p.ptr, p.len, ic );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p );
	return dst;
}

/* ReplaceChars maps one byte to one byte, so `with` contributes only its FIRST
** BYTE. On this family that is the first byte of the UTF-8 encoding, which for
** a non-ASCII replacement is a lead byte and not a character -- so a non-ASCII
** `with` is meaningless here and the call is a no-op instead. The ustring
** overload is where a non-ASCII replacement belongs. */
FBCALL FBSTRING *fb_StrReplaceChars( FBSTRING *s, FBUSTRING *set, FBUSTRING *with, int ic )
{
	const char *sp;
	ssize_t sl;
	FBSTRING *dst;
	char *out;
	HPAT p, r;

	hStrArg( s, &sp, &sl );
	hPatArg( set, &p );
	hPatArg( with, &r );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		if( r.len != 1 )
		{
			/* nothing usable to substitute: copy through unchanged */
			if( sl > 0 )
				memcpy( out, sp, sl );
			hStrTempTrim( dst, sl );
		}
		else
		{
			hb_hReplaceCharsFill( out, sp, sl, p.ptr, p.len, r.ptr[0], ic );
			hStrTempTrim( dst, sl );
		}
	}

	hPatRel( &p );
	hPatRel( &r );
	return dst;
}

FBCALL FBSTRING *fb_StrReverse( FBSTRING *s )
{
	const char *sp;
	ssize_t sl;
	FBSTRING *dst;
	char *out;

	hStrArg( s, &sp, &sl );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		hb_hReverseFill( out, sp, sl );
		hStrTempTrim( dst, sl );
	}

	return dst;
}

FBCALL FBSTRING *fb_StrRepeat( ssize_t count, FBSTRING *s )
{
	const char *sp;
	ssize_t sl, n, i;
	FBSTRING *dst;
	char *out;

	hStrArg( s, &sp, &sl );

	if( count <= 0 || sl <= 0 )
		return &__fb_ctx.null_desc;

	n = count * sl;

	dst = hStrTempAlloc( n, &out );
	if( out != NULL )
	{
		for( i = 0; i < count; i++ )
			memcpy( out + i * sl, sp, sl );
		hStrTempTrim( dst, n );
	}

	return dst;
}

FBCALL FBSTRING *fb_StrShrink( FBSTRING *s, FBUSTRING *mask )
{
	const char *sp;
	ssize_t sl, w;
	FBSTRING *dst;
	char *out;
	HPAT p;

	hStrArg( s, &sp, &sl );
	hPatArg( mask, &p );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		w = hb_hShrinkFill( out, sp, sl, p.ptr, p.len );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p );
	return dst;
}

FBCALL FBSTRING *fb_StrMCase( FBSTRING *s )
{
	const char *sp;
	ssize_t sl;
	FBSTRING *dst;
	char *out;

	hStrArg( s, &sp, &sl );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		hb_hMCaseFill( out, sp, sl );
		hStrTempTrim( dst, sl );
	}

	return dst;
}

FBCALL FBSTRING *fb_StrRemoveBetween
	(
		FBSTRING *s, FBUSTRING *d1, FBUSTRING *d2,
		int removeAll, ssize_t start, int ic
	)
{
	const char *sp;
	ssize_t sl, w;
	FBSTRING *dst;
	char *out;
	HPAT p1, p2;

	hStrArg( s, &sp, &sl );

	if( start < 1 )
		return hStrTempFrom( sp, sl );

	hPatArg( d1, &p1 );
	hPatArg( d2, &p2 );

	dst = hStrTempAlloc( sl, &out );
	if( out != NULL )
	{
		w = hb_hRemoveBetweenFill( out, sp, sl, p1.ptr, p1.len, p2.ptr, p2.len,
		                           removeAll, start - 1, ic );
		hStrTempTrim( dst, w );
	}

	hPatRel( &p1 );
	hPatRel( &p2 );
	return dst;
}
