/* ustring odds and ends: ASC, LSET/RSET, SWAP */

#include "fb.h"

static void hUStrRelTemp( void *src, ssize_t src_size )
{
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
}

/* ASC( s [, pos] ) -- returns the CODE UNIT at pos, 1-based.
**
** A code unit, not a codepoint: consistent with [] indexing and with LEN().
** ASC of a position holding a surrogate half therefore yields that half, which
** is what WSTRING already does on Windows. Decoding a whole scalar is the job
** of the codepoint helpers, not of ASC. */
FBCALL int fb_UStrAsc( void *src, ssize_t src_size, ssize_t pos )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len;
	int res;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( (pos >= 1) && (pos <= src_len) )
		res = (int)src_ptr[pos-1];
	else
		res = 0;

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();

	return res;
}

/* LSET / RSET.
**
** Both write into the destination WITHOUT resizing it, padding with spaces --
** that is what LSET/RSET mean for every FB string type. For a var-len ustring
** the current length is the field width. */
static void hUStrSet( void *dst, ssize_t dst_size, void *src, ssize_t src_size, int is_rset )
{
	FB_UCHAR *dst_ptr;
	const FB_UCHAR *src_ptr;
	ssize_t dst_len, src_len, i;

	FB_STRLOCK();

	FB_USTRSETUP( dst, dst_size, dst_ptr, dst_len );
	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( (dst_ptr != NULL) && (dst_len > 0) )
	{
		if( src_len > dst_len )
			src_len = dst_len;

		if( is_rset )
		{
			ssize_t pad = dst_len - src_len;
			for( i = 0; i < pad; i++ )
				dst_ptr[i] = (FB_UCHAR)' ';
			if( src_len > 0 )
				fb_hUStrCopyN( &dst_ptr[pad], src_ptr, src_len );
		}
		else
		{
			if( src_len > 0 )
				fb_hUStrCopyN( dst_ptr, src_ptr, src_len );
			for( i = src_len; i < dst_len; i++ )
				dst_ptr[i] = (FB_UCHAR)' ';
		}

		dst_ptr[dst_len] = 0;
	}

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();
}

FBCALL void fb_UStrLset( void *dst, ssize_t dst_size, void *src, ssize_t src_size )
{
	hUStrSet( dst, dst_size, src, src_size, 0 );
}

FBCALL void fb_UStrRset( void *dst, ssize_t dst_size, void *src, ssize_t src_size )
{
	hUStrSet( dst, dst_size, src, src_size, 1 );
}

/* SWAP for two var-len ustrings: exchange the descriptors, not the text.
**
** Swapping the three fields is O(1) and keeps both buffers alive, so neither
** side reallocates and no data is copied. */
FBCALL void fb_UStrSwap( void *str1, ssize_t size1, void *str2, ssize_t size2 )
{
	FB_STRLOCK();

	if( (size1 == FB_USTRSIZEVARLEN) && (size2 == FB_USTRSIZEVARLEN) )
	{
		FBUSTRING *a = (FBUSTRING *)str1;
		FBUSTRING *b = (FBUSTRING *)str2;
		FBUSTRING t;

		if( (a != NULL) && (b != NULL) )
		{
			t = *a;
			*a = *b;
			*b = t;
		}
	}
	else
	{
		/* at least one side is fixed-length, so the text has to move */
		FB_UCHAR *p1, *p2;
		ssize_t l1, l2, i, n;

		FB_USTRSETUP( str1, size1, p1, l1 );
		FB_USTRSETUP( str2, size2, p2, l2 );

		n = (l1 < l2) ? l2 : l1;

		for( i = 0; i < n; i++ )
		{
			FB_UCHAR c1 = (i < l1) ? p1[i] : (FB_UCHAR)' ';
			FB_UCHAR c2 = (i < l2) ? p2[i] : (FB_UCHAR)' ';
			if( i < l1 ) p1[i] = c2;
			if( i < l2 ) p2[i] = c1;
		}
	}

	FB_STRUNLOCK();
}
