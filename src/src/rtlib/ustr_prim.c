/* ustring primitives -- the hand-rolled replacements for the libc wide functions
**
** NONE of wcslen/wcsstr/wcsncmp/wcschr/wmemcpy/wmemset is used here, and none
** may be introduced later. On Windows FB_UCHAR is the same width as wchar_t so
** they would link and appear correct; on Linux wchar_t is 4 bytes and they
** would silently read the wrong stride. Using libc on one target and hand-rolled
** code on another is how two platforms drift apart -- see the header comment in
** fb_ustring.h.
**
** memcpy/memmove/memset ARE used: they are byte-oriented, present everywhere,
** and have no width assumption.
*/

#include "fb.h"

ssize_t fb_hUStrLen( const FB_UCHAR *s )
{
	const FB_UCHAR *p = s;

	if( s == NULL )
		return 0;

	while( *p != 0 )
		++p;

	return (ssize_t)(p - s);
}

/* Ordering is by CODE UNIT, which is what wcscmp does on Windows today and what
   every UTF-16 environment does. Note the known UTF-16 quirk this inherits:
   astral characters (encoded as surrogates, 0xD800..0xDFFF) sort BELOW the
   U+E000..U+FFFF range rather than above it. That is code-unit order, not
   codepoint order, and it is the conventional trade -- codepoint order would
   cost a decode per comparison. */
int fb_hUStrCompare( const FB_UCHAR *s1, ssize_t len1,
                     const FB_UCHAR *s2, ssize_t len2 )
{
	ssize_t i, minlen;

	if( s1 == NULL )
		return (s2 == NULL || len2 == 0) ? 0 : -1;
	if( s2 == NULL )
		return (len1 == 0) ? 0 : 1;

	minlen = (len1 < len2) ? len1 : len2;

	for( i = 0; i < minlen; i++ )
	{
		if( s1[i] != s2[i] )
			return (s1[i] < s2[i]) ? -1 : 1;
	}

	if( len1 == len2 )
		return 0;

	return (len1 < len2) ? -1 : 1;
}

/* Copy and NUL-terminate. */
void fb_hUStrCopy( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units )
{
	if( (src != NULL) && (units > 0) )
	{
		memcpy( dst, src, units * sizeof( FB_UCHAR ) );
		dst += units;
	}

	/* add the null-term */
	*dst = 0;
}

/* Copy without terminating -- for building a string in pieces. */
void fb_hUStrCopyN( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units )
{
	if( (src != NULL) && (units > 0) )
		memcpy( dst, src, units * sizeof( FB_UCHAR ) );
}

/* Overlap-safe copy, for in-place shifts (MID statement, LTRIM, ...). */
void fb_hUStrMove( FB_UCHAR *dst, const FB_UCHAR *src, ssize_t units )
{
	if( (src != NULL) && (units > 0) )
		memmove( dst, src, units * sizeof( FB_UCHAR ) );
}

void fb_hUStrFill( FB_UCHAR *dst, FB_UCHAR c, ssize_t units )
{
	ssize_t i;

	if( dst == NULL )
		return;

	/* memset is unusable for a 16-bit fill unless both bytes are equal;
	   take that fast path when we can, else fill by unit. */
	if( (c & 0xFF) == ((c >> 8) & 0xFF) )
	{
		if( units > 0 )
			memset( dst, c & 0xFF, units * sizeof( FB_UCHAR ) );
		return;
	}

	for( i = 0; i < units; i++ )
		dst[i] = c;
}

/* Index of the first occurrence of c, or -1. */
ssize_t fb_hUStrChr( const FB_UCHAR *s, ssize_t len, FB_UCHAR c )
{
	ssize_t i;

	if( s == NULL )
		return -1;

	for( i = 0; i < len; i++ )
	{
		if( s[i] == c )
			return i;
	}

	return -1;
}

/* Index of the first occurrence of needle in hay, or -1.
   Naive search, matching what the narrow side does -- the pattern is almost
   always short, and a sublinear algorithm would cost more in setup. */
ssize_t fb_hUStrStr( const FB_UCHAR *hay, ssize_t haylen,
                     const FB_UCHAR *needle, ssize_t needlelen )
{
	ssize_t i, j;

	if( (hay == NULL) || (needle == NULL) )
		return -1;

	/* an empty pattern matches at the start, as INSTR does */
	if( needlelen <= 0 )
		return 0;

	if( needlelen > haylen )
		return -1;

	for( i = 0; i <= haylen - needlelen; i++ )
	{
		if( hay[i] != needle[0] )
			continue;

		for( j = 1; j < needlelen; j++ )
		{
			if( hay[i+j] != needle[j] )
				break;
		}

		if( j == needlelen )
			return i;
	}

	return -1;
}

/* Skip leading units equal to c. Used by the trim family.
   NOTE the fixed-length case: USTRING*N buffers are padded with NULs, so
   callers strip those too -- same rule as fb_wstr_SkipChar. */
const FB_UCHAR *fb_hUStrSkipChar( const FB_UCHAR *s, ssize_t len, FB_UCHAR c )
{
	const FB_UCHAR *p = s;

	if( s == NULL )
		return NULL;

	while( (len > 0) && (*p == c) )
	{
		++p;
		--len;
	}

	return p;
}

/* Walk back over trailing units equal to c; returns a pointer one past the last
   kept unit. */
const FB_UCHAR *fb_hUStrSkipCharRev( const FB_UCHAR *s, ssize_t len, FB_UCHAR c )
{
	const FB_UCHAR *p;

	if( s == NULL )
		return NULL;

	p = s + len;

	while( (p > s) && (*(p-1) == c) )
		--p;

	return p;
}
