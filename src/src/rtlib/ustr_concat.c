/* ustring concatenation
**
** Port of str_concat.c / str_concatassign.c.
**
** fb_UStrConcat writes into a TEMP descriptor (fb_hUStrAllocTemp sets
** FB_TEMPSTRBIT), which is what lets the eventual fb_UStrAssign steal the
** buffer instead of copying it. Breaking that pairing is what turns
** a = b + c + d quadratic.
*/

#include "fb.h"

FBCALL FBUSTRING *fb_UStrConcat
	(
		FBUSTRING *dst,
		void *str1,
		ssize_t str1_size,
		void *str2,
		ssize_t str2_size
	)
{
	const FB_UCHAR *s1_ptr, *s2_ptr;
	ssize_t s1_len, s2_len;

	FB_STRLOCK();

	FB_USTRSETUP( str1, str1_size, s1_ptr, s1_len );
	FB_USTRSETUP( str2, str2_size, s2_ptr, s2_len );

	dst = fb_hUStrAllocTemp_NoLock( dst, s1_len + s2_len );

	if( dst != NULL && dst->data != NULL )
	{
		fb_hUStrCopyN( dst->data, s1_ptr, s1_len );
		/* NOT CopyN for the tail: this one terminates the result */
		fb_hUStrCopy( dst->data + s1_len, s2_ptr, s2_len );
	}

	/* release the operands if they were themselves temps */
	if( str1_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)str1 );
	if( str2_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)str2 );

	FB_STRUNLOCK();

	return dst;
}

/* dst &= src. For a var-len dst this grows in place, which is the whole point:
   the realloc policy in ustr_core.c gives geometric growth, so appending in a
   loop stays amortised O(1). */
FBCALL void *fb_UStrConcatAssign
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem
	)
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, dst_len;

	FB_STRLOCK();

	if( dst == NULL )
	{
		if( src_size == FB_USTRSIZEVARLEN )
			fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
		FB_STRUNLOCK();
		return dst;
	}

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( src_len > 0 )
	{
		if( dst_size == FB_USTRSIZEVARLEN )
		{
			FBUSTRING *dstr = (FBUSTRING *)dst;

			dst_len = FB_USTRSIZE( dstr );

			/* preserve == TRUE: the existing text must survive the grow */
			if( fb_hUStrRealloc( dstr, dst_len + src_len, FB_TRUE ) != NULL )
				fb_hUStrCopy( dstr->data + dst_len, src_ptr, src_len );
		}
		else
		{
			/* fixed-len or raw pointer: append up to the capacity and clamp */
			FB_UCHAR *dst_ptr = (FB_UCHAR *)dst;
			ssize_t cap;

			if( dst_size & FB_STRISFIXED )
				cap = dst_size & FB_STRSIZEMSK;
			else if( dst_size == 0 )
				cap = -1;                       /* unknown; assume big enough */
			else
				cap = dst_size - 1;

			dst_len = fb_hUStrLen( dst_ptr );

			if( cap >= 0 )
			{
				ssize_t room = cap - dst_len;
				if( room < 0 )
					room = 0;
				if( src_len > room )
					src_len = room;
			}

			if( src_len > 0 )
				fb_hUStrCopy( dst_ptr + dst_len, src_ptr, src_len );

			if( fill_rem != 0 && cap >= 0 )
			{
				ssize_t rem = cap - (dst_len + src_len);
				if( rem > 0 )
					fb_hUStrFill( &dst_ptr[dst_len + src_len + 1], 0, rem );
			}
		}
	}

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}
