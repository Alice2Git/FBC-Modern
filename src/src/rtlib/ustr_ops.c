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

#include "str_ops_core.h"

#undef FB_SOP_UNIT
#undef FB_SOP_UUNIT
#undef FB_SOP
#undef FB_SOP_FOLD

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

#undef FB_UPOS
