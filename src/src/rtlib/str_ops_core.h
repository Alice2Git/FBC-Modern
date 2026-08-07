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

/* ==========================================================================
** SPANS
**
** The extract family all answer the same question -- which run of the input
** comes back -- so they compute a (offset, count) span here and leave only the
** allocation to the width-specific wrapper. That keeps the index arithmetic,
** which is where these functions actually go wrong, in one place for both
** widths rather than transcribed twice.
**
** Spans are 0-based and always valid to slice: a miss is (0, 0), never a
** negative count.
** ========================================================================== */

/* Text BEFORE the first occurrence of pat at or after `from`.
**
** A MISS RETURNS THE WHOLE REMAINDER, not the empty string -- the PowerBASIC
** EXTRACT$ rule that AfxStrExtract carries. It is what makes a parse loop
** terminate naturally: the last field has no trailing delimiter, and this hands
** it back instead of losing it. Deliberately the opposite of hRemainSpan below,
** whose miss is empty; the two are complements and each is right on its own
** terms. An empty pattern is a miss, so it yields the whole remainder. */
static void FB_SOP(hExtractSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pat, ssize_t patlen,
		ssize_t from, int ic,
		ssize_t *off, ssize_t *cnt
	)
{
	ssize_t at;

	*off = 0;
	*cnt = 0;

	if( slen <= 0 || from < 0 || from >= slen )
		return;

	at = FB_SOP(hFind)( s, slen, pat, patlen, from, ic );

	*off = from;
	*cnt = (at < 0) ? (slen - from) : (at - from);
}

/* Text before the first character that is in `set`. Same miss rule. */
static void FB_SOP(hExtractCharsSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		ssize_t from, int ic,
		ssize_t *off, ssize_t *cnt
	)
{
	ssize_t at;

	*off = 0;
	*cnt = 0;

	if( slen <= 0 || from < 0 || from >= slen )
		return;

	at = FB_SOP(hFindAny)( s, slen, set, setlen, from, ic );

	*off = from;
	*cnt = (at < 0) ? (slen - from) : (at - from);
}

/* Text AFTER the first occurrence of pat at or after `from`.
**
** A MISS RETURNS EMPTY. Nothing followed the thing that was not there, and
** returning the whole remainder would make "everything after X" produce text
** that was never after anything. */
static void FB_SOP(hRemainSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pat, ssize_t patlen,
		ssize_t from, int ic,
		ssize_t *off, ssize_t *cnt
	)
{
	ssize_t at;

	*off = 0;
	*cnt = 0;

	if( slen <= 0 || patlen <= 0 || from < 0 || from >= slen )
		return;

	at = FB_SOP(hFind)( s, slen, pat, patlen, from, ic );
	if( at < 0 )
		return;

	*off = at + patlen;
	*cnt = slen - *off;
}

/* Text after the first character that is in `set`. Same miss rule. */
static void FB_SOP(hRemainCharsSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		ssize_t from, int ic,
		ssize_t *off, ssize_t *cnt
	)
{
	ssize_t at;

	*off = 0;
	*cnt = 0;

	if( slen <= 0 || setlen <= 0 || from < 0 || from >= slen )
		return;

	at = FB_SOP(hFindAny)( s, slen, set, setlen, from, ic );
	if( at < 0 )
		return;

	*off = at + 1;
	*cnt = slen - *off;
}

/* Text between the first d1 at or after `from` and the first d2 after THAT.
**
** Either delimiter missing yields empty -- there is no "between" without both
** ends. d2 is searched from the end of d1, never from `from`, so
** Between( "(a)(b)", "(", ")" ) is "a" and cannot match the second ")" first.
** An empty delimiter never matches, so it is a miss like any other. */
static void FB_SOP(hBetweenSpan)
	(
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *d1, ssize_t d1len,
		const FB_SOP_UNIT *d2, ssize_t d2len,
		ssize_t from, int ic,
		ssize_t *off, ssize_t *cnt
	)
{
	ssize_t a, b, inner;

	*off = 0;
	*cnt = 0;

	if( slen <= 0 || from < 0 || from >= slen )
		return;

	a = FB_SOP(hFind)( s, slen, d1, d1len, from, ic );
	if( a < 0 )
		return;

	inner = a + d1len;

	b = FB_SOP(hFind)( s, slen, d2, d2len, inner, ic );
	if( b < 0 )
		return;

	*off = inner;
	*cnt = b - inner;
}

/* ==========================================================================
** The remaining three are pure index arithmetic and never look at the text.
** They still live here rather than in the wrappers so that both widths get the
** same answer by construction instead of by review.
** ========================================================================== */

/* ClipLeft / ClipRight: a count of 0 or less removes nothing and returns the
** whole string; a count at or beyond the length removes all of it. Neither
** clamps into a negative span. */
static void FB_SOP(hClipLeftSpan)( ssize_t slen, ssize_t n, ssize_t *off, ssize_t *cnt )
{
	if( slen <= 0 || n >= slen )
	{
		*off = 0;
		*cnt = 0;
		return;
	}

	if( n <= 0 )
	{
		*off = 0;
		*cnt = slen;
		return;
	}

	*off = n;
	*cnt = slen - n;
}

static void FB_SOP(hClipRightSpan)( ssize_t slen, ssize_t n, ssize_t *off, ssize_t *cnt )
{
	*off = 0;

	if( slen <= 0 || n >= slen )
		*cnt = 0;
	else if( n <= 0 )
		*cnt = slen;
	else
		*cnt = slen - n;
}

/* DeleteAt: the run to REMOVE, given a 1-based start. A zero count means
** nothing is removed and the whole string comes back, which is what every
** invalid argument produces -- an out-of-range delete is a no-op, not an
** error and not a truncation. */
static void FB_SOP(hDeleteCut)
	(
		ssize_t slen, ssize_t start1, ssize_t count,
		ssize_t *coff, ssize_t *clen
	)
{
	*coff = 0;
	*clen = 0;

	if( slen <= 0 || start1 < 1 || count <= 0 || start1 > slen )
		return;

	*coff = start1 - 1;
	*clen = count;

	if( *clen > slen - *coff )
		*clen = slen - *coff;
}

/* InsertAt: the 0-based offset to splice at, or -1 for "do not insert".
**
** A position past the end APPENDS, which is the useful reading of "insert at
** position 20 of a 5-character string". A position below 1 does NOT insert --
** it returns the string untouched, matching hDeleteCut's treatment of an
** invalid start.
**
** NOTE: AfxStrInsert's comment says a position <= 0 appends; its code returns
** the string unchanged. The code is followed here, because appending on a
** negative index is the kind of silent success that hides a caller's off-by-one. */
static ssize_t FB_SOP(hInsertSplit)( ssize_t slen, ssize_t pos1 )
{
	if( pos1 < 1 )
		return -1;

	if( pos1 > slen )
		return slen;

	return pos1 - 1;
}

/* ==========================================================================
** TRANSFORMS
**
** These build a new string rather than slicing the old one, so each is a FILL:
** it writes into a caller-allocated buffer and returns how much it wrote. The
** caller sizes the buffer; every function here has a length the caller can
** compute in advance, which is why none of them needs a measure pass.
**
**   Replace       slen + count * (replen - patlen), count from hTally
**   Remove*       at most slen
**   Retain*       at most slen
**   ReplaceChars  exactly slen
**   Reverse       exactly slen
**   MCase         exactly slen
**   Shrink        at most slen
**   RemoveBetween at most slen
** ========================================================================== */

/* Replace every NON-OVERLAPPING occurrence of pat with rep.
**
** SINGLE PASS. The scan advances past each replacement and never re-examines
** what was just written, so a replacement containing the pattern does not
** cascade and cannot loop: Replace( "a", "a", "aa" ) is "aa", not a hang.
**
** The count that sizes the buffer comes from hTally, which walks with exactly
** this loop, so the two agree by construction rather than by review. An empty
** pattern matches nothing and copies the input through. */
static ssize_t FB_SOP(hReplaceFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *pat, ssize_t patlen,
		const FB_SOP_UNIT *rep, ssize_t replen,
		int ic
	)
{
	ssize_t i = 0, w = 0, at;

	if( patlen <= 0 || slen <= 0 )
	{
		if( slen > 0 )
			memcpy( dst, s, slen * sizeof( FB_SOP_UNIT ) );
		return (slen > 0) ? slen : 0;
	}

	while( (at = FB_SOP(hFind)( s, slen, pat, patlen, i, ic )) >= 0 )
	{
		if( at > i )
		{
			memcpy( &dst[w], &s[i], (at - i) * sizeof( FB_SOP_UNIT ) );
			w += at - i;
		}

		if( replen > 0 )
		{
			memcpy( &dst[w], rep, replen * sizeof( FB_SOP_UNIT ) );
			w += replen;
		}

		i = at + patlen;
	}

	if( slen > i )
	{
		memcpy( &dst[w], &s[i], (slen - i) * sizeof( FB_SOP_UNIT ) );
		w += slen - i;
	}

	return w;
}

/* Drop every unit that is in `set`. An empty set drops nothing. */
static ssize_t FB_SOP(hRemoveCharsFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		int ic
	)
{
	ssize_t i, w = 0;

	for( i = 0; i < slen; i++ )
	{
		if( setlen <= 0 || !FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			dst[w++] = s[i];
	}

	return w;
}

/* Keep only the units that are in `set` -- the complement of the above. An
** empty set keeps nothing, which is the complement of dropping nothing. */
static ssize_t FB_SOP(hRetainCharsFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		int ic
	)
{
	ssize_t i, w = 0;

	if( setlen <= 0 )
		return 0;

	for( i = 0; i < slen; i++ )
	{
		if( FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			dst[w++] = s[i];
	}

	return w;
}

/* Map every unit that is in `set` to `unit`. LENGTH NEVER CHANGES -- this is a
** one-for-one substitution, not a replacement, which is what makes offsets into
** the result still line up with the input. */
static ssize_t FB_SOP(hReplaceCharsFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *set, ssize_t setlen,
		FB_SOP_UNIT unit,
		int ic
	)
{
	ssize_t i;

	for( i = 0; i < slen; i++ )
	{
		if( setlen > 0 && FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], set, setlen, ic ) )
			dst[i] = unit;
		else
			dst[i] = s[i];
	}

	return slen;
}

/* Reverse.
**
** SURROGATE PAIRS ARE KEPT INTACT at the 16-bit width and not at the byte
** width, and that asymmetry is deliberate.
**
** A ustring is UTF-16 by definition, so reversing its code units blindly emits
** a low surrogate before its high one -- invalid UTF-16, every single time an
** astral character is present, not occasionally. AfxStrReverse does exactly
** that. Keeping the pair together costs one comparison per unit and is the only
** result that is still a string.
**
** A STRING is bytes with no declared encoding, so there is no pair to preserve
** and no way to know whether there would be one; bytes reverse as bytes. That
** does corrupt multi-byte UTF-8, and it is the only defensible answer for a
** type that does not say what it holds. Callers with UTF-8 in a STRING want the
** ustring overload.
**
** FB_SOP_ISHIGH/FB_SOP_ISLOW are constant 0 at the byte width, so the branch
** folds away there entirely. */
static void FB_SOP(hReverseFill)
	(
		FB_SOP_UNIT *dst, const FB_SOP_UNIT *s, ssize_t slen
	)
{
	ssize_t i = slen - 1, w = 0;

	while( i >= 0 )
	{
		if( i >= 1 &&
		    FB_SOP_ISLOW( (FB_SOP_UUNIT)s[i] ) &&
		    FB_SOP_ISHIGH( (FB_SOP_UUNIT)s[i-1] ) )
		{
			dst[w++] = s[i-1];
			dst[w++] = s[i];
			i -= 2;
		}
		else
		{
			dst[w++] = s[i];
			i -= 1;
		}
	}
}

/* Collapse runs of mask characters, and strip them from both ends.
**
** Every maximal run of characters that are in `mask` becomes a single copy of
** mask[0], and leading and trailing runs are removed outright. So the result is
** words separated by exactly one mask[0].
**
** An EMPTY MASK returns the input unchanged -- there is nothing to shrink.
** (AfxStrShrink returns the EMPTY STRING for an empty mask. That looks like a
** guard clause that fell through to the wrong variable, and "shrink by nothing"
** destroying the input is not a behaviour worth preserving.) */
static ssize_t FB_SOP(hShrinkFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *mask, ssize_t masklen
	)
{
	ssize_t i = 0, w = 0;
	int pending = 0;

	if( masklen <= 0 )
	{
		if( slen > 0 )
			memcpy( dst, s, slen * sizeof( FB_SOP_UNIT ) );
		return (slen > 0) ? slen : 0;
	}

	for( i = 0; i < slen; i++ )
	{
		if( FB_SOP(hInSet)( (FB_SOP_UUNIT)s[i], mask, masklen, 0 ) )
		{
			/* remember it, but only emit if a word follows -- that is
			   what strips the trailing run without a second pass */
			if( w > 0 )
				pending = 1;
		}
		else
		{
			if( pending )
			{
				dst[w++] = mask[0];
				pending = 0;
			}
			dst[w++] = s[i];
		}
	}

	return w;
}

/* Title case: the first letter of each word upper, everything else lower.
**
** A WORD STARTS after any character that is not alphanumeric. That is a
** different rule from AfxNova's, which tests against a fixed list of
** punctuation -- so DWStrMCase capitalises after "." and "-" but not after "/"
** or "_" or a tab, which is an omission rather than a decision. "Not
** alphanumeric" needs no list and has no gaps.
**
** Non-ASCII counts as a word character: an accented letter continues a word,
** and a CJK character has no case to change anyway. */
static ssize_t FB_SOP(hMCaseFill)
	(
		FB_SOP_UNIT *dst, const FB_SOP_UNIT *s, ssize_t slen
	)
{
	ssize_t i;
	int startsWord = 1;

	for( i = 0; i < slen; i++ )
	{
		FB_SOP_UUNIT c = (FB_SOP_UUNIT)s[i];

		if( startsWord )
			dst[i] = (FB_SOP_UNIT)FB_SOP_UPPER( c );
		else
			dst[i] = (FB_SOP_UNIT)FB_SOP_LOWER( c );

		startsWord = !FB_SOP_ISWORD( c );
	}

	return slen;
}

/* Remove from each `d1` through the matching `d2`, delimiters included.
**
** `removeAll` decides whether this happens once or until no pair is left.
** Either delimiter missing stops the walk and copies the rest through, so an
** unbalanced opener is left alone rather than swallowing the tail.
**
** d2 is searched from the END of d1, so the pair cannot be crossed -- the same
** rule hBetweenSpan follows, and for the same reason. */
static ssize_t FB_SOP(hRemoveBetweenFill)
	(
		FB_SOP_UNIT *dst,
		const FB_SOP_UNIT *s, ssize_t slen,
		const FB_SOP_UNIT *d1, ssize_t d1len,
		const FB_SOP_UNIT *d2, ssize_t d2len,
		int removeAll, ssize_t from, int ic
	)
{
	ssize_t i = 0, w = 0, a, b;

	if( slen <= 0 )
		return 0;

	if( from < 0 )
		from = 0;
	if( from > slen )
		from = slen;

	/* everything before `from` is untouched */
	if( from > 0 )
	{
		memcpy( dst, s, from * sizeof( FB_SOP_UNIT ) );
		w = from;
	}
	i = from;

	for( ;; )
	{
		a = FB_SOP(hFind)( s, slen, d1, d1len, i, ic );
		if( a < 0 )
			break;

		b = FB_SOP(hFind)( s, slen, d2, d2len, a + d1len, ic );
		if( b < 0 )
			break;

		if( a > i )
		{
			memcpy( &dst[w], &s[i], (a - i) * sizeof( FB_SOP_UNIT ) );
			w += a - i;
		}

		i = b + d2len;

		if( !removeAll )
			break;
	}

	if( slen > i )
	{
		memcpy( &dst[w], &s[i], (slen - i) * sizeof( FB_SOP_UNIT ) );
		w += slen - i;
	}

	return w;
}
