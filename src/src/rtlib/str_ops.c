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

#include "str_ops_core.h"

#undef FB_SOP_UNIT
#undef FB_SOP_UUNIT
#undef FB_SOP
#undef FB_SOP_FOLD

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
