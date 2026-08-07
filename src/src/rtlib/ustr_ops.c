/* FB.* string algorithms, 16-BIT width -- the USTRING and WSTRING entry points.
**
** The algorithms are in str_ops_core.h; this file supplies the UTF-16
** instantiation, the FBCALL wrappers, and the WSTRING bridge.
**
** ARGUMENTS: USTRING IS A DESCRIPTOR, WSTRING IS A POINTER.
**
** A `byref as const ustring` parameter carries an FBUSTRING descriptor for every
** argument form -- measured: a var-len USTRING passes its own descriptor, and a
** USTRING * N gets a compiler-built temporary one. A `byref as const wstring`
** parameter carries a raw NUL-terminated FB_WCHAR pointer with no descriptor at
** all, so the two need different unpacking and get different entry points.
**
** THE WSTRING BRIDGE, AND WHY IT IS NOT ALWAYS FREE.
**
** FB_WCHAR is 2 bytes on Windows and 4 on Linux. Where it is 2 a wstring already
** IS UTF-16, so the bridge is a pointer reinterpret and a strlen -- no copy, no
** allocation. Where it is wider the text has to be re-encoded into a temporary,
** which is a real cost per call, and the fallback below pays it honestly rather
** than pretending the widths are interchangeable.
**
** WSTRING functions RETURN the ustring family's answers. There is no dynamic
** WSTRING to return, so anything producing text hands back a USTRING; the
** inspection functions here return integers and booleans, so the question does
** not arise until Phase 2.
**
** CASE FOLDING is the generated simple BMP table in ustr_casetable.c, reached
** through fb_hUStrToUpper -- NOT towupper(), which is locale-dependent and would
** make the same string fold differently depending on the user's locale and on
** which libc the program linked against. Astral characters have no simple case
** mapping and pass through unchanged.
*/

#include "fb.h"

/* --- the 16-bit instantiation of str_ops_core.h --- */

#define FB_SOP_UNIT      FB_UCHAR
#define FB_SOP_UUNIT     FB_UCHAR
#define FB_SOP(name)     hu_##name
#define FB_SOP_FOLD(c)   fb_hUStrToUpper( c )
#define FB_SOP_UPPER(c)  fb_hUStrToUpper( c )
#define FB_SOP_LOWER(c)  fb_hUStrToLower( c )

/* A word character, for title case. ASCII alphanumerics plus everything
** non-ASCII: an accented letter continues a word, and a CJK character is a word
** character with no case to change. */
#define FB_SOP_ISWORD(c) ( ((c) >= '0' && (c) <= '9') ||                            ((c) >= 'A' && (c) <= 'Z') ||                            ((c) >= 'a' && (c) <= 'z') || ((c) >= 0x80) )

/* Real surrogate tests here -- this is the width where a pair exists, and where
** hReverseFill must not split one. */
#define FB_SOP_ISHIGH(c) FB_UCHAR_IS_HIGHSUR(c)
#define FB_SOP_ISLOW(c)  FB_UCHAR_IS_LOWSUR(c)

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

static const FB_UCHAR hUStrEmpty[1] = { 0 };

static void hUStrArg( FBUSTRING *s, const FB_UCHAR **ptr, ssize_t *len )
{
	if( s == NULL || s->data == NULL )
	{
		*ptr = hUStrEmpty;
		*len = 0;
	}
	else
	{
		*ptr = s->data;
		*len = s->len;
	}
}

/* --- the WSTRING bridge ---
**
** hWstrArg() yields a (ptr, len) pair and a cleanup token. Where FB_WCHAR is 16
** bits the token is NULL and the pair points straight at the caller's buffer;
** otherwise the token is a temp descriptor that hWstrRel() must release.
**
** Only the FIRST argument ever needs it. Every later string parameter is typed
** USTRING in all three overloads -- that is what makes fbc resolve the set on
** the first parameter at all -- so it arrives as a descriptor and is unpacked by
** hUStrArg() exactly as in the USTRING family. */

typedef struct { FBUSTRING *tmp; } HWSTRARG;

static void hWstrArg
	(
		const FB_WCHAR *w, const FB_UCHAR **ptr, ssize_t *len, HWSTRARG *tok
	)
{
	tok->tmp = NULL;

	if( w == NULL )
	{
		*ptr = hUStrEmpty;
		*len = 0;
		return;
	}

	/* Branch on sizeof rather than #if, following ustr_wchar_conv.h: it folds
	** away at compile time just the same, and the branch that is dead on this
	** target still gets compiled and type-checked instead of rotting. */
	if( sizeof( FB_WCHAR ) == 2 )
	{
		/* already UTF-16 -- reinterpret, no conversion and no allocation */
		*ptr = (const FB_UCHAR *)w;
		*len = (ssize_t)fb_wstr_Len( w );
	}
	else
	{
		/* wider (or narrower) wchar: re-encode into a temp we must release */
		tok->tmp = fb_WstrToUStr( w );
		hUStrArg( tok->tmp, ptr, len );
	}
}

static void hWstrRel( HWSTRARG *tok )
{
	if( tok->tmp != NULL )
	{
		FB_STRLOCK();
		fb_hUStrDelTemp_NoLock( tok->tmp );
		FB_STRUNLOCK();
		tok->tmp = NULL;
	}
}

/* --- search and inspect, USTRING ---
**
** Positions are 1-based, 0 means not found, and every length and position counts
** CODE UNITS -- matching LEN, [] and INSTR on a ustring. An astral character is
** a surrogate pair and therefore counts as 2. Searching by code unit needs no
** surrogate awareness: a surrogate half can never equal a BMP unit, so a match
** can never land mid-character. */

#define FB_UPOS( at )    ( ((at) < 0) ? 0 : (at) + 1 )

FBCALL ssize_t fb_UStrTally( FBUSTRING *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );

	return hu_hTally( sp, sl, pp, pl, ic );
}

FBCALL ssize_t fb_UStrTallyChars( FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return hu_hTallyAny( sp, sl, tp, tl, ic );
}

FBCALL ssize_t fb_UStrInstrChars( ssize_t start, FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	if( start < 1 )
		return 0;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return FB_UPOS( hu_hFindAny( sp, sl, tp, tl, start - 1, ic ) );
}

FBCALL ssize_t fb_UStrVerifySet( ssize_t start, FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	if( start < 1 )
		return 0;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return FB_UPOS( hu_hVerify( sp, sl, tp, tl, start - 1, ic ) );
}

FBCALL ssize_t fb_UStrSpanOf( ssize_t start, FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	if( start < 1 )
		return 0;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return hu_hSpan( sp, sl, tp, tl, start - 1, ic );
}

FBCALL int fb_UStrStartsWith( FBUSTRING *s, FBUSTRING *pre, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pre, &pp, &pl );

	return hu_hStartsWith( sp, sl, pp, pl, ic );
}

FBCALL int fb_UStrEndsWith( FBUSTRING *s, FBUSTRING *suf, int ic )
{
	const FB_UCHAR *sp, *fp;
	ssize_t sl, fl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( suf, &fp, &fl );

	return hu_hEndsWith( sp, sl, fp, fl, ic );
}

FBCALL int fb_UStrContains( FBUSTRING *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );

	if( pl <= 0 )
		return 1;

	return hu_hFind( sp, sl, pp, pl, 0, ic ) >= 0;
}

/* --- search and inspect, WSTRING ---
**
** Same answers as the USTRING family above. Only the HAYSTACK goes through the
** bridge; the pattern is already a ustring descriptor, because every parameter
** after the first is typed USTRING in all three overloads.
**
** Written out rather than macro-generated: the eight bodies differ only in the
** call, but a macro that has to carry `start` in three of them and not in the
** other five stops paying for itself. */

FBCALL ssize_t fb_WStrTally( const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = hu_hTally( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL ssize_t fb_WStrTallyChars( const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = hu_hTallyAny( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL ssize_t fb_WStrInstrChars( ssize_t start, const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, r;
	HWSTRARG t1;

	if( start < 1 )
		return 0;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = FB_UPOS( hu_hFindAny( sp, sl, tp, tl, start - 1, ic ) );

	hWstrRel( &t1 );
	return r;
}

FBCALL ssize_t fb_WStrVerifySet( ssize_t start, const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, r;
	HWSTRARG t1;

	if( start < 1 )
		return 0;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = FB_UPOS( hu_hVerify( sp, sl, tp, tl, start - 1, ic ) );

	hWstrRel( &t1 );
	return r;
}

FBCALL ssize_t fb_WStrSpanOf( ssize_t start, const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, r;
	HWSTRARG t1;

	if( start < 1 )
		return 0;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = hu_hSpan( sp, sl, tp, tl, start - 1, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL int fb_WStrStartsWith( const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;
	int r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = hu_hStartsWith( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL int fb_WStrEndsWith( const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;
	int r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = hu_hEndsWith( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL int fb_WStrContains( const FB_WCHAR *s, FBUSTRING *arg, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;
	int r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( arg, &tp, &tl );

	r = (tl <= 0) ? 1 : (hu_hFind( sp, sl, tp, tl, 0, ic ) >= 0);

	hWstrRel( &t1 );
	return r;
}


/* --- extract family, 16-bit width ---
**
** Both the USTRING and the WSTRING overloads RETURN A USTRING. There is no
** dynamic WSTRING to hand back, and a fixed one would need a caller-supplied
** buffer. A ustring on Windows already IS UTF-16, so passing the result straight
** to a wide API costs nothing.
**
** The result is a temp descriptor the CALLER frees, exactly as in the byte
** family. Nothing here releases its own arguments -- those belong to the caller.
**
** Spans come from str_ops_core.h, so the offsets are computed by the same code
** the byte family uses and the two widths cannot disagree. */

static FBUSTRING *hUTempFrom( const FB_UCHAR *src, ssize_t units )
{
	FBUSTRING *dst;

	if( units <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp( NULL, units );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	if( dst->data != NULL )
	{
		fb_hUStrCopy( dst->data, src, units );
		dst->data[units] = 0;
	}

	return dst;
}

static FBUSTRING *hUTempFrom2
	(
		const FB_UCHAR *a, ssize_t alen, const FB_UCHAR *b, ssize_t blen
	)
{
	FBUSTRING *dst;
	ssize_t n = alen + blen;

	if( n <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	if( dst->data != NULL )
	{
		if( alen > 0 )
			fb_hUStrCopy( dst->data, a, alen );
		if( blen > 0 )
			fb_hUStrCopy( dst->data + alen, b, blen );
		dst->data[n] = 0;
	}

	return dst;
}

/* head[0..at-1] + ins + head[at..slen-1] */
static FBUSTRING *hUSplice
	(
		const FB_UCHAR *s, ssize_t slen, ssize_t at,
		const FB_UCHAR *ins, ssize_t inslen
	)
{
	FBUSTRING *dst;
	ssize_t n = slen + inslen;

	if( n <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	if( dst->data != NULL )
	{
		if( at > 0 )
			fb_hUStrCopy( dst->data, s, at );
		if( inslen > 0 )
			fb_hUStrCopy( dst->data + at, ins, inslen );
		if( slen - at > 0 )
			fb_hUStrCopy( dst->data + at + inslen, s + at, slen - at );
		dst->data[n] = 0;
	}

	return dst;
}

/* ----------------------------------------------------------------- USTRING */

FBCALL FBUSTRING *fb_UStrExtract( ssize_t start, FBUSTRING *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl, off, cnt;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );

	hu_hExtractSpan( sp, sl, pp, pl, start - 1, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrExtractChars( ssize_t start, FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, off, cnt;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	hu_hExtractCharsSpan( sp, sl, tp, tl, start - 1, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrRemain( FBUSTRING *s, FBUSTRING *pat, ssize_t start, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl, off, cnt;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );

	hu_hRemainSpan( sp, sl, pp, pl, start - 1, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrRemainChars( FBUSTRING *s, FBUSTRING *set, ssize_t start, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, off, cnt;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	hu_hRemainCharsSpan( sp, sl, tp, tl, start - 1, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrBetween
	(
		FBUSTRING *s, FBUSTRING *d1, FBUSTRING *d2, ssize_t start, int ic
	)
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl, off, cnt;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hUStrArg( s, &sp, &sl );
	hUStrArg( d1, &ap, &al );
	hUStrArg( d2, &bp, &bl );

	hu_hBetweenSpan( sp, sl, ap, al, bp, bl, start - 1, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrClipLeft( FBUSTRING *s, ssize_t n )
{
	const FB_UCHAR *sp;
	ssize_t sl, off, cnt;

	hUStrArg( s, &sp, &sl );
	hu_hClipLeftSpan( sl, n, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrClipRight( FBUSTRING *s, ssize_t n )
{
	const FB_UCHAR *sp;
	ssize_t sl, off, cnt;

	hUStrArg( s, &sp, &sl );
	hu_hClipRightSpan( sl, n, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

FBCALL FBUSTRING *fb_UStrDeleteAt( FBUSTRING *s, ssize_t start, ssize_t count )
{
	const FB_UCHAR *sp;
	ssize_t sl, coff, clen;

	hUStrArg( s, &sp, &sl );
	hu_hDeleteCut( sl, start, count, &coff, &clen );

	if( clen <= 0 )
		return hUTempFrom( sp, sl );

	return hUTempFrom2( sp, coff, sp + coff + clen, sl - coff - clen );
}

FBCALL FBUSTRING *fb_UStrInsertAt( FBUSTRING *s, FBUSTRING *ins, ssize_t pos )
{
	const FB_UCHAR *sp, *ip;
	ssize_t sl, il, at;

	hUStrArg( s, &sp, &sl );

	at = hu_hInsertSplit( sl, pos );
	if( at < 0 )
		return hUTempFrom( sp, sl );

	hUStrArg( ins, &ip, &il );

	return hUSplice( sp, sl, at, ip, il );
}

/* ----------------------------------------------------------------- WSTRING */

FBCALL FBUSTRING *fb_WStrExtract( ssize_t start, const FB_WCHAR *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pat, &pp, &pl );

	hu_hExtractSpan( sp, sl, pp, pl, start - 1, ic, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrExtractChars( ssize_t start, const FB_WCHAR *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( set, &tp, &tl );

	hu_hExtractCharsSpan( sp, sl, tp, tl, start - 1, ic, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRemain( const FB_WCHAR *s, FBUSTRING *pat, ssize_t start, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pat, &pp, &pl );

	hu_hRemainSpan( sp, sl, pp, pl, start - 1, ic, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRemainChars( const FB_WCHAR *s, FBUSTRING *set, ssize_t start, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( set, &tp, &tl );

	hu_hRemainCharsSpan( sp, sl, tp, tl, start - 1, ic, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrBetween
	(
		const FB_WCHAR *s, FBUSTRING *d1, FBUSTRING *d2, ssize_t start, int ic
	)
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	if( start < 1 )
		return &__fb_ctx.unull_desc;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( d1, &ap, &al );
	hUStrArg( d2, &bp, &bl );

	hu_hBetweenSpan( sp, sl, ap, al, bp, bl, start - 1, ic, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrClipLeft( const FB_WCHAR *s, ssize_t n )
{
	const FB_UCHAR *sp;
	ssize_t sl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hu_hClipLeftSpan( sl, n, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrClipRight( const FB_WCHAR *s, ssize_t n )
{
	const FB_UCHAR *sp;
	ssize_t sl, off, cnt;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hu_hClipRightSpan( sl, n, &off, &cnt );
	r = hUTempFrom( sp + off, cnt );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrDeleteAt( const FB_WCHAR *s, ssize_t start, ssize_t count )
{
	const FB_UCHAR *sp;
	ssize_t sl, coff, clen;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hu_hDeleteCut( sl, start, count, &coff, &clen );

	if( clen <= 0 )
		r = hUTempFrom( sp, sl );
	else
		r = hUTempFrom2( sp, coff, sp + coff + clen, sl - coff - clen );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrInsertAt( const FB_WCHAR *s, FBUSTRING *ins, ssize_t pos )
{
	const FB_UCHAR *sp, *ip;
	ssize_t sl, il, at;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );

	at = hu_hInsertSplit( sl, pos );
	if( at < 0 )
	{
		r = hUTempFrom( sp, sl );
	}
	else
	{
		hUStrArg( ins, &ip, &il );
		r = hUSplice( sp, sl, at, ip, il );
	}

	hWstrRel( &t1 );
	return r;
}


/* --- transform family, 16-bit width ---
**
** USTRING and WSTRING overloads, both returning a USTRING. The lengths are all
** computable before the write, so none of these needs a measure pass.
**
** The USTRING and WSTRING bodies differ only in how the haystack is unpacked, so
** each pair shares a static worker that takes an already-unpacked (ptr, len).
** That is what keeps the two from drifting -- the earlier families paid for the
** duplication in review instead. */

static FBUSTRING *hUTempAlloc( ssize_t n, FB_UCHAR **out )
{
	FBUSTRING *dst;

	*out = NULL;

	if( n <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp( NULL, n );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	*out = dst->data;
	return dst;
}

static void hUTempTrim( FBUSTRING *dst, ssize_t written )
{
	if( dst->data == NULL )
		return;

	fb_hUStrSetLength( dst, written );
	dst->data[written] = 0;
}

/* ------------------------------------------------------------- the workers */

static FBUSTRING *hUReplace
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *pp, ssize_t pl,
		const FB_UCHAR *rp, ssize_t rl,
		int ic
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;
	ssize_t count, n, w;

	count = hu_hTally( sp, sl, pp, pl, ic );
	n = sl + count * (rl - pl);

	dst = hUTempAlloc( n, &out );
	if( out != NULL )
	{
		w = hu_hReplaceFill( out, sp, sl, pp, pl, rp, rl, ic );
		hUTempTrim( dst, w );
	}

	return dst;
}

static FBUSTRING *hURemoveChars
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *tp, ssize_t tl, int ic
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hRemoveCharsFill( out, sp, sl, tp, tl, ic ) );

	return dst;
}

static FBUSTRING *hURetainChars
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *tp, ssize_t tl, int ic
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hRetainCharsFill( out, sp, sl, tp, tl, ic ) );

	return dst;
}

/* One code unit for one code unit, so `with` must be EXACTLY ONE UNIT. An
** astral replacement is two units and has no one-for-one form, so it is a
** no-op rather than a silent half-character. */
static FBUSTRING *hUReplaceChars
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *tp, ssize_t tl,
		const FB_UCHAR *rp, ssize_t rl, int ic
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
	{
		if( rl != 1 )
			memcpy( out, sp, sl * sizeof( FB_UCHAR ) );
		else
			hu_hReplaceCharsFill( out, sp, sl, tp, tl, rp[0], ic );

		hUTempTrim( dst, sl );
	}

	return dst;
}

static FBUSTRING *hUReverse( const FB_UCHAR *sp, ssize_t sl )
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
	{
		hu_hReverseFill( out, sp, sl );
		hUTempTrim( dst, sl );
	}

	return dst;
}

static FBUSTRING *hURepeat( ssize_t count, const FB_UCHAR *sp, ssize_t sl )
{
	FBUSTRING *dst;
	FB_UCHAR *out;
	ssize_t n, i;

	if( count <= 0 || sl <= 0 )
		return &__fb_ctx.unull_desc;

	n = count * sl;

	dst = hUTempAlloc( n, &out );
	if( out != NULL )
	{
		for( i = 0; i < count; i++ )
			memcpy( out + i * sl, sp, sl * sizeof( FB_UCHAR ) );
		hUTempTrim( dst, n );
	}

	return dst;
}

static FBUSTRING *hUShrink
	(
		const FB_UCHAR *sp, ssize_t sl, const FB_UCHAR *mp, ssize_t ml
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hShrinkFill( out, sp, sl, mp, ml ) );

	return dst;
}

static FBUSTRING *hUMCase( const FB_UCHAR *sp, ssize_t sl )
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
	{
		hu_hMCaseFill( out, sp, sl );
		hUTempTrim( dst, sl );
	}

	return dst;
}

static FBUSTRING *hURemoveBetween
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *ap, ssize_t al,
		const FB_UCHAR *bp, ssize_t bl,
		int removeAll, ssize_t from, int ic
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hRemoveBetweenFill( out, sp, sl, ap, al, bp, bl,
		                                        removeAll, from, ic ) );

	return dst;
}

/* ----------------------------------------------------------------- USTRING */

FBCALL FBUSTRING *fb_UStrReplace( FBUSTRING *s, FBUSTRING *pat, FBUSTRING *rep, int ic )
{
	const FB_UCHAR *sp, *pp, *rp;
	ssize_t sl, pl, rl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );
	hUStrArg( rep, &rp, &rl );

	return hUReplace( sp, sl, pp, pl, rp, rl, ic );
}

FBCALL FBUSTRING *fb_UStrRemove( FBUSTRING *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pat, &pp, &pl );

	return hUReplace( sp, sl, pp, pl, NULL, 0, ic );
}

FBCALL FBUSTRING *fb_UStrRemoveChars( FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return hURemoveChars( sp, sl, tp, tl, ic );
}

FBCALL FBUSTRING *fb_UStrRetainChars( FBUSTRING *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return hURetainChars( sp, sl, tp, tl, ic );
}

FBCALL FBUSTRING *fb_UStrReplaceChars( FBUSTRING *s, FBUSTRING *set, FBUSTRING *with, int ic )
{
	const FB_UCHAR *sp, *tp, *rp;
	ssize_t sl, tl, rl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );
	hUStrArg( with, &rp, &rl );

	return hUReplaceChars( sp, sl, tp, tl, rp, rl, ic );
}

FBCALL FBUSTRING *fb_UStrReverse( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hUReverse( sp, sl );
}

FBCALL FBUSTRING *fb_UStrRepeat( ssize_t count, FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hURepeat( count, sp, sl );
}

FBCALL FBUSTRING *fb_UStrShrink( FBUSTRING *s, FBUSTRING *mask )
{
	const FB_UCHAR *sp, *mp;
	ssize_t sl, ml;

	hUStrArg( s, &sp, &sl );
	hUStrArg( mask, &mp, &ml );

	return hUShrink( sp, sl, mp, ml );
}

FBCALL FBUSTRING *fb_UStrMCase( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hUMCase( sp, sl );
}

FBCALL FBUSTRING *fb_UStrRemoveBetween
	(
		FBUSTRING *s, FBUSTRING *d1, FBUSTRING *d2,
		int removeAll, ssize_t start, int ic
	)
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;

	hUStrArg( s, &sp, &sl );

	if( start < 1 )
	{
		hUStrArg( s, &sp, &sl );
		return hUTempFrom( sp, sl );
	}

	hUStrArg( d1, &ap, &al );
	hUStrArg( d2, &bp, &bl );

	return hURemoveBetween( sp, sl, ap, al, bp, bl, removeAll, start - 1, ic );
}

/* ----------------------------------------------------------------- WSTRING */

FBCALL FBUSTRING *fb_WStrReplace( const FB_WCHAR *s, FBUSTRING *pat, FBUSTRING *rep, int ic )
{
	const FB_UCHAR *sp, *pp, *rp;
	ssize_t sl, pl, rl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pat, &pp, &pl );
	hUStrArg( rep, &rp, &rl );

	r = hUReplace( sp, sl, pp, pl, rp, rl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRemove( const FB_WCHAR *s, FBUSTRING *pat, int ic )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pat, &pp, &pl );

	r = hUReplace( sp, sl, pp, pl, NULL, 0, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRemoveChars( const FB_WCHAR *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( set, &tp, &tl );

	r = hURemoveChars( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRetainChars( const FB_WCHAR *s, FBUSTRING *set, int ic )
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( set, &tp, &tl );

	r = hURetainChars( sp, sl, tp, tl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrReplaceChars( const FB_WCHAR *s, FBUSTRING *set, FBUSTRING *with, int ic )
{
	const FB_UCHAR *sp, *tp, *rp;
	ssize_t sl, tl, rl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( set, &tp, &tl );
	hUStrArg( with, &rp, &rl );

	r = hUReplaceChars( sp, sl, tp, tl, rp, rl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrReverse( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hUReverse( sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRepeat( ssize_t count, const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hURepeat( count, sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrShrink( const FB_WCHAR *s, FBUSTRING *mask )
{
	const FB_UCHAR *sp, *mp;
	ssize_t sl, ml;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( mask, &mp, &ml );

	r = hUShrink( sp, sl, mp, ml );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrMCase( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hUMCase( sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrRemoveBetween
	(
		const FB_WCHAR *s, FBUSTRING *d1, FBUSTRING *d2,
		int removeAll, ssize_t start, int ic
	)
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );

	if( start < 1 )
	{
		r = hUTempFrom( sp, sl );
	}
	else
	{
		hUStrArg( d1, &ap, &al );
		hUStrArg( d2, &bp, &bl );
		r = hURemoveBetween( sp, sl, ap, al, bp, bl, removeAll, start - 1, ic );
	}

	hWstrRel( &t1 );
	return r;
}


/* --- pad, wrap, escape, predicates: 16-bit width --- */

/* One code unit, so any BMP character pads. An astral pad is two units and has
** no one-unit form, so a space is used rather than a lone surrogate. */
static FB_UCHAR hUPadUnit( const FB_UCHAR *p, ssize_t plen )
{
	if( plen == 1 )
		return p[0];

	return (FB_UCHAR)' ';
}

static FBUSTRING *hUPad
	(
		const FB_UCHAR *sp, ssize_t sl,
		ssize_t width, FB_UCHAR pad, int mode
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( width, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hPadFill( out, sp, sl, width, pad, mode ) );

	return dst;
}

static FBUSTRING *hUWrap
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *ap, ssize_t al,
		const FB_UCHAR *bp, ssize_t bl
	)
{
	FBUSTRING *dst;
	FB_UCHAR *out;
	ssize_t n;

	/* an empty closing means "same as opening" */
	if( bl <= 0 )
	{
		bp = ap;
		bl = al;
	}

	n = al + sl + bl;

	dst = hUTempAlloc( n, &out );
	if( out != NULL )
	{
		if( al > 0 )
			memcpy( out, ap, al * sizeof( FB_UCHAR ) );
		if( sl > 0 )
			memcpy( out + al, sp, sl * sizeof( FB_UCHAR ) );
		if( bl > 0 )
			memcpy( out + al + sl, bp, bl * sizeof( FB_UCHAR ) );
		hUTempTrim( dst, n );
	}

	return dst;
}

static FBUSTRING *hUUnwrap
	(
		const FB_UCHAR *sp, ssize_t sl,
		const FB_UCHAR *ap, ssize_t al,
		const FB_UCHAR *bp, ssize_t bl, int ic
	)
{
	ssize_t off, cnt;

	if( bl <= 0 )
	{
		bp = ap;
		bl = al;
	}

	hu_hUnwrapSpan( sp, sl, ap, al, bp, bl, ic, &off, &cnt );

	return hUTempFrom( sp + off, cnt );
}

static FBUSTRING *hUEscape( const FB_UCHAR *sp, ssize_t sl )
{
	FBUSTRING *dst;
	FB_UCHAR *out;
	ssize_t n;

	n = hu_hEscapeFill( NULL, sp, sl );

	dst = hUTempAlloc( n, &out );
	if( out != NULL )
	{
		hu_hEscapeFill( out, sp, sl );
		hUTempTrim( dst, n );
	}

	return dst;
}

static FBUSTRING *hUUnescape( const FB_UCHAR *sp, ssize_t sl )
{
	FBUSTRING *dst;
	FB_UCHAR *out;

	dst = hUTempAlloc( sl, &out );
	if( out != NULL )
		hUTempTrim( dst, hu_hUnescapeFill( out, sp, sl ) );

	return dst;
}

/* ----------------------------------------------------------------- USTRING */

FBCALL FBUSTRING *fb_UStrPadRight( FBUSTRING *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pad, &pp, &pl );

	return hUPad( sp, sl, width, hUPadUnit( pp, pl ), 0 );
}

FBCALL FBUSTRING *fb_UStrPadLeft( FBUSTRING *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pad, &pp, &pl );

	return hUPad( sp, sl, width, hUPadUnit( pp, pl ), 1 );
}

FBCALL FBUSTRING *fb_UStrPadCenter( FBUSTRING *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( pad, &pp, &pl );

	return hUPad( sp, sl, width, hUPadUnit( pp, pl ), 2 );
}

FBCALL FBUSTRING *fb_UStrWrap( FBUSTRING *s, FBUSTRING *op, FBUSTRING *cl )
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( op, &ap, &al );
	hUStrArg( cl, &bp, &bl );

	return hUWrap( sp, sl, ap, al, bp, bl );
}

FBCALL FBUSTRING *fb_UStrUnwrap( FBUSTRING *s, FBUSTRING *op, FBUSTRING *cl, int ic )
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( op, &ap, &al );
	hUStrArg( cl, &bp, &bl );

	return hUUnwrap( sp, sl, ap, al, bp, bl, ic );
}

FBCALL FBUSTRING *fb_UStrEscape( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hUEscape( sp, sl );
}

FBCALL FBUSTRING *fb_UStrUnescape( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hUUnescape( sp, sl );
}

FBCALL int fb_UStrIsNumeric( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hu_hIsNumeric( sp, sl );
}

FBCALL int fb_UStrIsBlank( FBUSTRING *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;

	hUStrArg( s, &sp, &sl );

	return hu_hIsBlank( sp, sl );
}

/* ----------------------------------------------------------------- WSTRING */

FBCALL FBUSTRING *fb_WStrPadRight( const FB_WCHAR *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pad, &pp, &pl );

	r = hUPad( sp, sl, width, hUPadUnit( pp, pl ), 0 );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrPadLeft( const FB_WCHAR *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pad, &pp, &pl );

	r = hUPad( sp, sl, width, hUPadUnit( pp, pl ), 1 );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrPadCenter( const FB_WCHAR *s, ssize_t width, FBUSTRING *pad )
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( pad, &pp, &pl );

	r = hUPad( sp, sl, width, hUPadUnit( pp, pl ), 2 );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrWrap( const FB_WCHAR *s, FBUSTRING *op, FBUSTRING *cl )
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( op, &ap, &al );
	hUStrArg( cl, &bp, &bl );

	r = hUWrap( sp, sl, ap, al, bp, bl );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrUnwrap( const FB_WCHAR *s, FBUSTRING *op, FBUSTRING *cl, int ic )
{
	const FB_UCHAR *sp, *ap, *bp;
	ssize_t sl, al, bl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	hUStrArg( op, &ap, &al );
	hUStrArg( cl, &bp, &bl );

	r = hUUnwrap( sp, sl, ap, al, bp, bl, ic );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrEscape( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hUEscape( sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL FBUSTRING *fb_WStrUnescape( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	FBUSTRING *r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hUUnescape( sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL int fb_WStrIsNumeric( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	int r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hu_hIsNumeric( sp, sl );

	hWstrRel( &t1 );
	return r;
}

FBCALL int fb_WStrIsBlank( const FB_WCHAR *s )
{
	const FB_UCHAR *sp;
	ssize_t sl;
	int r;
	HWSTRARG t1;

	hWstrArg( s, &sp, &sl, &t1 );
	r = hu_hIsBlank( sp, sl );

	hWstrRel( &t1 );
	return r;
}


/* --- split boundaries, 16-bit width ---
**
** Only a USTRING entry point: the WSTRING overload in inc/fb/string.bi converts
** to a ustring first and reuses this, because its result is an
** Array( of ustring ) either way and a second C path would only duplicate the
** boundary logic. */

FBCALL ssize_t fb_UStrSplitSpans
	(
		FBUSTRING *s, FBUSTRING *delim, int ic, ssize_t *out, ssize_t maxpairs
	)
{
	const FB_UCHAR *sp, *pp;
	ssize_t sl, pl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( delim, &pp, &pl );

	return hu_hSplitSpans( sp, sl, pp, pl, ic, out, maxpairs );
}

FBCALL ssize_t fb_UStrSplitCharsSpans
	(
		FBUSTRING *s, FBUSTRING *set, int ic, ssize_t *out, ssize_t maxpairs
	)
{
	const FB_UCHAR *sp, *tp;
	ssize_t sl, tl;

	hUStrArg( s, &sp, &sl );
	hUStrArg( set, &tp, &tl );

	return hu_hSplitCharsSpans( sp, sl, tp, tl, ic, out, maxpairs );
}

#undef FB_UPOS
