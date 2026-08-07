/* ustring searching: INSTR, INSTRREV, and their Any forms
**
** Positions are 1-based and 0 means "not found", matching every other FB string
** type. Positions are in CODE UNITS, consistent with LEN() and [] indexing.
**
** Searching by code unit is safe for UTF-16 without any surrogate awareness: a
** surrogate half can never equal a BMP unit, and a two-unit pattern can only
** match at a real pair boundary. So a match can never land mid-character, which
** is the one thing a naive byte search over UTF-8 would get wrong.
*/

#include "fb.h"

static void hUStrRelTemp( void *src, ssize_t src_size )
{
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
}

/* INSTR( [start,] src, pattern ) */
FBCALL ssize_t fb_UStrInstr
	(
		ssize_t start,
		void *src, ssize_t src_size,
		void *pat, ssize_t pat_size
	)
{
	const FB_UCHAR *src_ptr, *pat_ptr;
	ssize_t src_len, pat_len, res;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );
	FB_USTRSETUP( pat, pat_size, pat_ptr, pat_len );

	res = 0;

	if( (start > 0) && (start <= src_len) && (pat_len > 0) )
	{
		ssize_t at = fb_hUStrStr( &src_ptr[start-1], src_len - (start-1),
		                          pat_ptr, pat_len );
		if( at >= 0 )
			res = start + at;
	}

	hUStrRelTemp( src, src_size );
	hUStrRelTemp( pat, pat_size );

	FB_STRUNLOCK();

	return res;
}

/* INSTR( [start,] src, ANY set ) -- first unit that appears in the set */
FBCALL ssize_t fb_UStrInstrAny
	(
		ssize_t start,
		void *src, ssize_t src_size,
		void *set, ssize_t set_size
	)
{
	const FB_UCHAR *src_ptr, *set_ptr;
	ssize_t src_len, set_len, i, j, res;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );
	FB_USTRSETUP( set, set_size, set_ptr, set_len );

	res = 0;

	if( (start > 0) && (start <= src_len) && (set_len > 0) )
	{
		for( i = start - 1; i < src_len; i++ )
		{
			for( j = 0; j < set_len; j++ )
			{
				if( src_ptr[i] == set_ptr[j] )
				{
					res = i + 1;
					break;
				}
			}
			if( res != 0 )
				break;
		}
	}

	hUStrRelTemp( src, src_size );
	hUStrRelTemp( set, set_size );

	FB_STRUNLOCK();

	return res;
}

/* INSTRREV( src, pattern [, start] ). start <= 0 means "from the end". */
FBCALL ssize_t fb_UStrInstrRev
	(
		void *src, ssize_t src_size,
		void *pat, ssize_t pat_size,
		ssize_t start
	)
{
	const FB_UCHAR *src_ptr, *pat_ptr;
	ssize_t src_len, pat_len, i, j, res;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );
	FB_USTRSETUP( pat, pat_size, pat_ptr, pat_len );

	res = 0;

	if( (src_len > 0) && (pat_len > 0) && (pat_len <= src_len) && (start != 0) )
	{
		if( start < 0 )
			start = src_len - pat_len + 1;
		else if( start > src_len - pat_len + 1 )
			start = src_len - pat_len + 1;

		for( i = start - 1; i >= 0; i-- )
		{
			for( j = 0; j < pat_len; j++ )
			{
				if( src_ptr[i+j] != pat_ptr[j] )
					break;
			}
			if( j == pat_len )
			{
				res = i + 1;
				break;
			}
		}
	}

	hUStrRelTemp( src, src_size );
	hUStrRelTemp( pat, pat_size );

	FB_STRUNLOCK();

	return res;
}

/* INSTRREV( src, ANY set [, start] ) */
FBCALL ssize_t fb_UStrInstrRevAny
	(
		void *src, ssize_t src_size,
		void *set, ssize_t set_size,
		ssize_t start
	)
{
	const FB_UCHAR *src_ptr, *set_ptr;
	ssize_t src_len, set_len, i, j, res;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );
	FB_USTRSETUP( set, set_size, set_ptr, set_len );

	res = 0;

	if( (src_len > 0) && (set_len > 0) && (start != 0) )
	{
		if( (start < 0) || (start > src_len) )
			start = src_len;

		for( i = start - 1; i >= 0; i-- )
		{
			for( j = 0; j < set_len; j++ )
			{
				if( src_ptr[i] == set_ptr[j] )
				{
					res = i + 1;
					break;
				}
			}
			if( res != 0 )
				break;
		}
	}

	hUStrRelTemp( src, src_size );
	hUStrRelTemp( set, set_size );

	FB_STRUNLOCK();

	return res;
}
