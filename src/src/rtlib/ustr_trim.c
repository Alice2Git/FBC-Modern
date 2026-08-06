/* ustring trimming: TRIM, LTRIM, RTRIM, and their Any/Ex forms
**
** Plain TRIM strips spaces. It also strips NULs, because a USTRING * N buffer is
** zero-filled past its text and callers expect the padding gone -- the same rule
** fb_wstr_SkipChar() follows for WSTRING * N.
**
** All of these are CODE UNIT operations; none of them decode. Trimming a space
** or a caller-supplied unit never needs to know about surrogates, since neither
** half of a surrogate pair can equal a BMP unit.
*/

#include "fb.h"

static FBUSTRING *hUStrTempFrom( const FB_UCHAR *src, ssize_t units )
{
	FBUSTRING *dst;

	if( units <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp_NoLock( NULL, units );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	if( dst->data != NULL )
		fb_hUStrCopy( dst->data, src, units );

	return dst;
}

static void hUStrRelTemp( void *src, ssize_t src_size )
{
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
}

/* Is c one of the units in set[0..setlen-1]? */
static int hInSet( FB_UCHAR c, const FB_UCHAR *set, ssize_t setlen )
{
	ssize_t i;
	for( i = 0; i < setlen; i++ )
	{
		if( set[i] == c )
			return 1;
	}
	return 0;
}

/* The single implementation behind all nine entry points.
     mode: 1 = left, 2 = right, 3 = both
     set == NULL -> strip spaces and NULs */
static FBUSTRING *hUStrTrim
	(
		void *src, ssize_t src_size,
		const FB_UCHAR *set, ssize_t setlen,
		int mode
	)
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, first, last;
	FBUSTRING *dst;

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	first = 0;
	last = src_len;

	if( mode & 1 )
	{
		while( first < last )
		{
			FB_UCHAR c = src_ptr[first];
			if( set != NULL )
			{
				if( hInSet( c, set, setlen ) == 0 ) break;
			}
			else
			{
				if( (c != (FB_UCHAR)' ') && (c != 0) ) break;
			}
			first++;
		}
	}

	if( mode & 2 )
	{
		while( last > first )
		{
			FB_UCHAR c = src_ptr[last-1];
			if( set != NULL )
			{
				if( hInSet( c, set, setlen ) == 0 ) break;
			}
			else
			{
				if( (c != (FB_UCHAR)' ') && (c != 0) ) break;
			}
			last--;
		}
	}

	dst = hUStrTempFrom( &src_ptr[first], last - first );

	return dst;
}

/* ---------------------------------------------------------------- plain */

FBCALL FBUSTRING *fb_UStrTrim( void *src, ssize_t src_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrim( src, src_size, NULL, 0, 3 );
	hUStrRelTemp( src, src_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrLTrim( void *src, ssize_t src_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrim( src, src_size, NULL, 0, 1 );
	hUStrRelTemp( src, src_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrRTrim( void *src, ssize_t src_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrim( src, src_size, NULL, 0, 2 );
	hUStrRelTemp( src, src_size );
	FB_STRUNLOCK();
	return dst;
}

/* ------------------------------------------------------------------- Ex
   Strip one specific string from the ends, not a set of units. */

static FBUSTRING *hUStrTrimEx
	(
		void *src, ssize_t src_size,
		void *pat, ssize_t pat_size,
		int mode
	)
{
	const FB_UCHAR *src_ptr, *pat_ptr;
	ssize_t src_len, pat_len, first, last;
	FBUSTRING *dst;

	FB_USTRSETUP( src, src_size, src_ptr, src_len );
	FB_USTRSETUP( pat, pat_size, pat_ptr, pat_len );

	first = 0;
	last = src_len;

	if( pat_len > 0 )
	{
		if( mode & 1 )
		{
			while( (last - first) >= pat_len )
			{
				ssize_t i;
				for( i = 0; i < pat_len; i++ )
					if( src_ptr[first+i] != pat_ptr[i] ) break;
				if( i < pat_len ) break;
				first += pat_len;
			}
		}

		if( mode & 2 )
		{
			while( (last - first) >= pat_len )
			{
				ssize_t i;
				for( i = 0; i < pat_len; i++ )
					if( src_ptr[last-pat_len+i] != pat_ptr[i] ) break;
				if( i < pat_len ) break;
				last -= pat_len;
			}
		}
	}

	dst = hUStrTempFrom( &src_ptr[first], last - first );

	return dst;
}

FBCALL FBUSTRING *fb_UStrTrimEx( void *src, ssize_t src_size, void *pat, ssize_t pat_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrimEx( src, src_size, pat, pat_size, 3 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( pat, pat_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrLTrimEx( void *src, ssize_t src_size, void *pat, ssize_t pat_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrimEx( src, src_size, pat, pat_size, 1 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( pat, pat_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrRTrimEx( void *src, ssize_t src_size, void *pat, ssize_t pat_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrTrimEx( src, src_size, pat, pat_size, 2 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( pat, pat_size );
	FB_STRUNLOCK();
	return dst;
}

/* ------------------------------------------------------------------ Any
   Strip any of the units in the given set. */

FBCALL FBUSTRING *fb_UStrTrimAny( void *src, ssize_t src_size, void *set, ssize_t set_size )
{
	const FB_UCHAR *set_ptr;
	ssize_t set_len;
	FBUSTRING *dst;
	FB_STRLOCK();
	FB_USTRSETUP( set, set_size, set_ptr, set_len );
	dst = hUStrTrim( src, src_size, set_ptr, set_len, 3 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( set, set_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrLTrimAny( void *src, ssize_t src_size, void *set, ssize_t set_size )
{
	const FB_UCHAR *set_ptr;
	ssize_t set_len;
	FBUSTRING *dst;
	FB_STRLOCK();
	FB_USTRSETUP( set, set_size, set_ptr, set_len );
	dst = hUStrTrim( src, src_size, set_ptr, set_len, 1 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( set, set_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrRTrimAny( void *src, ssize_t src_size, void *set, ssize_t set_size )
{
	const FB_UCHAR *set_ptr;
	ssize_t set_len;
	FBUSTRING *dst;
	FB_STRLOCK();
	FB_USTRSETUP( set, set_size, set_ptr, set_len );
	dst = hUStrTrim( src, src_size, set_ptr, set_len, 2 );
	hUStrRelTemp( src, src_size );
	hUStrRelTemp( set, set_size );
	FB_STRUNLOCK();
	return dst;
}
