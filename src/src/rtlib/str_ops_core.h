/* The FB.* string algorithms, written once and instantiated per code-unit width.
**
** This header is included TWICE, from str_ops.c with FB_SOP_UNIT = char and from
** ustr_ops.c with FB_SOP_UNIT = FB_UCHAR, and it defines only static helpers.
** It is the pattern con_print_raw_uni.h and ustr_wchar_conv.h already use, taken
** for the same reason: two hand-maintained copies of a search loop drift, and
** the drift shows up as one width quietly disagreeing with the other on an edge
** case nobody tests twice.
**
** WHAT THE CALLER MUST DEFINE BEFORE INCLUDING
**
**   FB_SOP_UNIT       the code unit type
**   FB_SOP_UUNIT      its unsigned form, for comparisons
**   FB_SOP_FOLD(c)    case fold, one unit in and one unit out
**   FB_SOP(name)      name-mangling macro, so the two instantiations do not
**                     collide at link time
**
** POSITIONS
**
** Every helper here is 0-BASED and returns -1 for "not found". The 1-based,
** 0-means-not-found convention FreeBASIC uses at the language level is applied
** once, in the FBCALL wrappers, rather than threaded through the algorithms --
** off-by-ones live at conversion boundaries, so there is exactly one.
**
** CODE UNITS, NOT CHARACTERS
**
** Every length and position counts code units, matching LEN, [] and INSTR on
** both STRING and USTRING. For the 16-bit instantiation this is safe for UTF-16
** without any surrogate awareness -- a surrogate half can never equal a BMP
** unit, so a match can never land mid-character. ustr_search.c documents the
** same reasoning at more length.
**
** CASE FOLDING
**
** Folding is a per-unit map supplied by the includer: ASCII for the byte width
** (a STRING has no declared encoding, so anything else would be a locale guess)
** and the generated BMP table for the 16-bit width. "Simple" in both cases --
** one unit in, one out -- so a fold never changes a length and every offset
** stays valid. Astral characters have no simple mapping and pass through.
*/

/* Compare two runs, honouring the fold flag. */
static int FB_SOP(hEq)
	(
		const FB_SOP_UNIT *a, const FB_SOP_UNIT *b, ssize_t len, int ic
	)
{
	ssize_t i;

	if( !ic )
		return memcmp( a, b, len * sizeof( FB_SOP_UNIT ) ) == 0;

	for( i = 0; i < len; i++ )
	{
		if( FB_SOP_FOLD( (FB_SOP_UUNIT)a[i] ) != FB_SOP_FOLD( (FB_SOP_UUNIT)b[i] ) )
			return 0;
	}

	return 1;
}

/* Is c one of set[0..setlen-1]? */
static int FB_SOP(hInSet)
	(
		FB_SOP_UUNIT c, const FB_SOP_UNIT *set, ssize_t setlen, int ic
	)
{
	ssize_t i;

	if( ic )
	{
		FB_SOP_UUNIT fc = FB_SOP_FOLD( c );
		for( i = 0; i < setlen; i++ )
		{
			if( FB_SOP_FOLD( (FB_SOP_UUNIT)set[i] ) == fc )
				return 1;
		}
	}
	else
	{
		for( i = 0; i < setlen; i++ )
		{
			if( (FB_SOP_UUNIT)set[i] == c )
				return 1;
		}
	}

	return 0;
}

/* First index >= from where pat occurs, or -1.
**
** An EMPTY PATTERN RETURNS -1, not `from`. FreeBASIC's own INSTR answers 0 for
** an empty pattern, and every function layered on this one -- Tally, Replace,
** Split -- would otherwise have to special-case a zero-width match that matches
** everywhere and advances nothing. One rule, stated once. */
static ssize_t FB_SOP(hFind)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pat, ssize_t patlen,
		ssize_t from, int ic
	)
{
	ssize_t i, last;

	if( patlen <= 0 || slen <= 0 || from < 0 )
		return -1;

	last = slen - patlen;
	for( i = from; i <= last; i++ )
	{
		if( FB_SOP(hEq)( &s[i], pat, patlen, ic ) )
			return i;
	}

	return -1;
}

/* First index >= from whose unit IS in set, or -1. */
static ssize_t FB_SOP(hFindAny)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		ssize_t from, int ic
	)
{
	ssize_t i;

	if( setlen <= 0 || slen <= 0 || from < 0 )
		return -1;

	for( i = from; i < slen; i++ )
	{
		if( FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			return i;
	}

	return -1;
}

/* First index >= from whose unit is NOT in set, or -1 -- the VerifySet answer.
**
** An EMPTY SET makes position `from` the answer, because nothing is in the set
** and so the first unit already fails it. That is the opposite of hFindAny's
** empty-set rule, and deliberately so: "find one of nothing" cannot succeed,
** "find one that is not among nothing" cannot fail. */
static ssize_t FB_SOP(hVerify)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		ssize_t from, int ic
	)
{
	ssize_t i;

	if( slen <= 0 || from < 0 || from >= slen )
		return -1;

	for( i = from; i < slen; i++ )
	{
		if( !FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			return i;
	}

	return -1;
}

/* How many units from `from` onward are in set, stopping at the first that is
** not -- the SpanOf answer, and always >= 0. */
static ssize_t FB_SOP(hSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		ssize_t from, int ic
	)
{
	ssize_t i;

	if( slen <= 0 || from < 0 || from >= slen )
		return 0;

	for( i = from; i < slen; i++ )
	{
		if( !FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			break;
	}

	return i - from;
}

/* Count of NON-OVERLAPPING occurrences of pat.
**
** Non-overlapping is the choice Replace and Split need: the count has to be the
** number of things that would be replaced or the number of separators, and an
** overlapping count is neither. So "aaaa" contains "aa" TWICE, not three times.
** Documented rather than assumed, because the other answer is just as defensible
** in isolation. */
static ssize_t FB_SOP(hTally)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pat, ssize_t patlen,
		int ic
	)
{
	ssize_t at, n = 0, i = 0;

	if( patlen <= 0 || slen <= 0 )
		return 0;

	while( (at = FB_SOP(hFind)( s, slen, pat, patlen, i, ic )) >= 0 )
	{
		n++;
		i = at + patlen;
	}

	return n;
}

/* Count of units that are in set. */
static ssize_t FB_SOP(hTallyAny)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		int ic
	)
{
	ssize_t i, n = 0;

	if( setlen <= 0 || slen <= 0 )
		return 0;

	for( i = 0; i < slen; i++ )
	{
		if( FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			n++;
	}

	return n;
}

/* An EMPTY affix is present in every string, including the empty one -- the
** vacuous-truth answer, and the one that keeps StartsWith(s,"") consistent with
** hFind's "" never matching by making this NOT go through hFind. */
static int FB_SOP(hStartsWith)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pre, ssize_t prelen,
		int ic
	)
{
	if( prelen <= 0 )
		return 1;
	if( prelen > slen )
		return 0;

	return FB_SOP(hEq)( s, pre, prelen, ic );
}

static int FB_SOP(hEndsWith)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *suf, ssize_t suflen,
		int ic
	)
{
	if( suflen <= 0 )
		return 1;
	if( suflen > slen )
		return 0;

	return FB_SOP(hEq)( &s[slen - suflen], suf, suflen, ic );
}
