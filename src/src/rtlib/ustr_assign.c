/* ustring assignment
**
** Port of str_assign.c. Two deliberate differences from the narrow version:
**
**  1. A fixed-length USTRING * N is NUL-TERMINATED and its remainder is zeroed,
**     following WSTRING * N and ZSTRING * N. It does NOT space-pad the way
**     STRING * N does -- that padding is a QB-compatibility artifact and is
**     wrong for a Unicode text buffer.
**  2. There is no "fixed-len zstring vs zstring ptr" split, because a raw
**     FB_UCHAR * has only one meaning.
**
** The temp-stealing fast path is carried over unchanged and matters a great
** deal: without it, a = b + c + d copies the whole accumulating string at every
** step instead of moving one descriptor.
*/

#include "fb.h"

FBCALL void *fb_UStrAssignEx
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem,
		int is_init
	)
{
	FBUSTRING *dstr;
	const FB_UCHAR *src_ptr;
	ssize_t src_len;

	FB_STRLOCK();

	if( dst == NULL )
	{
		if( src_size == FB_USTRSIZEVARLEN )
			fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

		FB_STRUNLOCK();

		return dst;
	}

	/* src */
	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	/* is dst var-len? */
	if( dst_size == FB_USTRSIZEVARLEN )
	{
		dstr = (FBUSTRING *)dst;

		/* src empty? */
		if( src_len == 0 )
		{
			if( is_init == FB_FALSE )
			{
				fb_UStrDelete( dstr );
			}
			else
			{
				dstr->data = NULL;
				dstr->len = 0;
				dstr->size = 0;
			}
		}
		else
		{
			/* if src is a temp, steal the descriptor instead of copying */
			if( (src_size == FB_USTRSIZEVARLEN) && FB_UISTEMP(src) )
			{
				if( is_init == FB_FALSE )
					fb_UStrDelete( dstr );

				dstr->data = (FB_UCHAR *)src_ptr;
				dstr->len = src_len;
				dstr->size = ((FBUSTRING *)src)->size;

				((FBUSTRING *)src)->data = NULL;
				((FBUSTRING *)src)->len = 0;
				((FBUSTRING *)src)->size = 0;

				fb_hUStrDelTempDesc( (FBUSTRING *)src );

				FB_STRUNLOCK();

				return dst;
			}

			/* else, realloc dst if needed and copy src */
			if( is_init == FB_FALSE )
			{
				if( FB_USTRSIZE( dst ) != src_len )
					fb_hUStrRealloc( dstr, src_len, FB_FALSE );
			}
			else
			{
				fb_hUStrAlloc( dstr, src_len );
			}

			if( dstr->data != NULL )
				fb_hUStrCopy( dstr->data, src_ptr, src_len );
		}
	}
	/* fixed-len USTRING * N -- dst_size counts usable units, excluding the
	   terminator, and the buffer physically holds one more */
	else if( dst_size & FB_STRISFIXED )
	{
		FB_UCHAR *dst_ptr = (FB_UCHAR *)dst;

		dst_size &= FB_STRSIZEMSK;

		if( src_len > dst_size )
			src_len = dst_size;

		if( src_len > 0 )
			fb_hUStrCopyN( dst_ptr, src_ptr, src_len );

		dst_ptr[src_len] = 0;

		/* zero the remainder so the buffer never carries stale units past the
		   terminator -- the trim helpers strip trailing NULs and rely on it */
		if( fill_rem != 0 )
		{
			ssize_t rem = dst_size - src_len;
			if( rem > 0 )
				fb_hUStrFill( &dst_ptr[src_len + 1], 0, rem );
		}
	}
	/* raw FB_UCHAR * */
	else
	{
		FB_UCHAR *dst_ptr = (FB_UCHAR *)dst;

		if( src_len == 0 )
		{
			*dst_ptr = 0;
		}
		else
		{
			/* as in C, a bare pointer is assumed large enough */
			if( dst_size == 0 )
				dst_size = src_len;
			else
			{
				/* less the null-term */
				--dst_size;

				if( dst_size < src_len )
					src_len = dst_size;
			}

			fb_hUStrCopy( dst_ptr, src_ptr, src_len );
		}

		if( fill_rem != 0 )
		{
			dst_size -= src_len;
			if( dst_size > 0 )
				fb_hUStrFill( &dst_ptr[src_len], 0, dst_size );
		}
	}

	/* delete temp? */
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

FBCALL void *fb_UStrAssign
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem
	)
{
	return fb_UStrAssignEx( dst, dst_size, src, src_size, fill_rem, FB_FALSE );
}

FBCALL void *fb_UStrInit
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem
	)
{
	return fb_UStrAssignEx( dst, dst_size, src, src_size, fill_rem, FB_TRUE );
}
