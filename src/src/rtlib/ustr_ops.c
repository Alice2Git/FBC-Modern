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

#undef FB_UPOS
