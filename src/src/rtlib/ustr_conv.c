/* ustring <-> narrow string conversion
**
** ENCODING POLICY (D5): the byte world is UTF-8, on every target. Malformed
** input becomes U+FFFD rather than failing.
**
** This deliberately differs from how STRING <-> WSTRING behaves, which goes
** through the C locale (mbstowcs/wcstombs) and is therefore codepage- and
** platform-dependent. A ustring must convert identically everywhere or it is
** not portable, which is the entire point of the type.
**
** THE CONSEQUENCE, STATED PLAINLY: arbitrary binary does not round-trip through
** a ustring. Bytes that are not valid UTF-8 become U+FFFD and the originals are
** gone. Binary belongs in STRING, which is unchanged and still available.
*/

#include "fb.h"

/* ------------------------------------------------------------------ helpers */

/* Decode UTF-8 bytes into a freshly allocated ustring descriptor's buffer.
   Returns dst, or NULL on allocation failure. */
static FBUSTRING *hUStrFromBytes( FBUSTRING *dst, const char *src, ssize_t src_bytes, int is_init )
{
	ssize_t units;

	if( src_bytes <= 0 )
	{
		if( is_init == FB_FALSE )
			fb_UStrDelete( dst );
		else
		{
			dst->data = NULL;
			dst->len = 0;
			dst->size = 0;
		}
		return dst;
	}

	/* measure exactly, then fill: one extra pass, but the descriptor ends up
	   sized to the text rather than to the UTF-8 worst case */
	units = fb_hUtf8ToUtf16( src, src_bytes, NULL, 0 );

	if( is_init == FB_FALSE )
	{
		if( fb_hUStrRealloc( dst, units, FB_FALSE ) == NULL )
			return NULL;
	}
	else
	{
		if( fb_hUStrAlloc( dst, units ) == NULL )
			return NULL;
	}

	fb_hUtf8ToUtf16( src, src_bytes, dst->data, units );

	return dst;
}

/* ---------------------------------------------- narrow -> ustring (assign) */

FBCALL void *fb_UStrAssignFromA
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem,
		int is_init
	)
{
	const char *src_ptr;
	ssize_t src_len;

	FB_STRLOCK();

	if( dst == NULL )
	{
		if( src_size == FB_STRSIZEVARLEN )
			fb_hStrDelTemp_NoLock( (FBSTRING *)src );
		FB_STRUNLOCK();
		return dst;
	}

	/* the narrow side's length is authoritative, so embedded NULs survive
	   into the ustring instead of truncating it */
	FB_STRSETUP_FIX( src, src_size, src_ptr, src_len );

	if( dst_size == FB_USTRSIZEVARLEN )
	{
		hUStrFromBytes( (FBUSTRING *)dst, src_ptr, src_len, is_init );
	}
	else
	{
		/* fixed-len or raw pointer destination: decode into a scratch buffer,
		   then hand it to the normal assign so clamping and the terminator are
		   handled in exactly one place */
		ssize_t units = fb_hUtf8ToUtf16( src_ptr, src_len, NULL, 0 );
		FB_UCHAR *tmp = (FB_UCHAR *)malloc( (units + 1) * sizeof( FB_UCHAR ) );

		if( tmp != NULL )
		{
			fb_hUtf8ToUtf16( src_ptr, src_len, tmp, units );

			FB_STRUNLOCK();
			fb_UStrAssignEx( dst, dst_size, tmp,
			                 (units | FB_STRISFIXED), fill_rem, is_init );
			FB_STRLOCK();

			free( tmp );
		}
	}

	if( src_size == FB_STRSIZEVARLEN )
		fb_hStrDelTemp_NoLock( (FBSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* ---------------------------------------------- ustring -> narrow (assign) */

FBCALL void *fb_UStrAssignToA
	(
		void *dst,
		ssize_t dst_size,
		void *src,
		ssize_t src_size,
		int fill_rem,
		int is_init
	)
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, nbytes;
	char *tmp;

	FB_STRLOCK();

	if( dst == NULL )
	{
		if( src_size == FB_USTRSIZEVARLEN )
			fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
		FB_STRUNLOCK();
		return dst;
	}

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	nbytes = fb_hUtf16ToUtf8( src_ptr, src_len, NULL, 0 );
	tmp = (char *)malloc( nbytes + 1 );

	if( tmp != NULL )
	{
		fb_hUtf16ToUtf8( src_ptr, src_len, tmp, nbytes );

		/* hand off to the narrow assign, so STRING*N padding, ZSTRING*N
		   clamping and the temp-stealing rules all stay in one place */
		FB_STRUNLOCK();
		fb_StrAssignEx( dst, dst_size, tmp, (nbytes | FB_STRISFIXED),
		                fill_rem, is_init );
		FB_STRLOCK();

		free( tmp );
	}

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* ------------------------------------------------ expression conversions */

/* narrow -> ustring, as a temp. Used where a conversion appears inside an
   expression rather than as the whole of an assignment. */
FBCALL FBUSTRING *fb_StrToUStr( void *src, ssize_t src_size )
{
	const char *src_ptr;
	ssize_t src_len, units;
	FBUSTRING *dst;

	FB_STRLOCK();

	FB_STRSETUP_FIX( src, src_size, src_ptr, src_len );

	units = fb_hUtf8ToUtf16( src_ptr, src_len, NULL, 0 );

	dst = fb_hUStrAllocTemp_NoLock( NULL, units );
	if( dst != NULL )
	{
		if( dst->data != NULL )
			fb_hUtf8ToUtf16( src_ptr, src_len, dst->data, units );
	}
	else
	{
		dst = &__fb_ctx.unull_desc;
	}

	if( src_size == FB_STRSIZEVARLEN )
		fb_hStrDelTemp_NoLock( (FBSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* ustring -> narrow, as a temp. */
FBCALL FBSTRING *fb_UStrToStr( void *src, ssize_t src_size )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, nbytes;
	FBSTRING *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	nbytes = fb_hUtf16ToUtf8( src_ptr, src_len, NULL, 0 );

	dst = fb_hStrAllocTemp_NoLock( NULL, nbytes );
	if( dst != NULL )
	{
		if( dst->data != NULL )
			fb_hUtf16ToUtf8( src_ptr, src_len, dst->data, nbytes );
	}
	else
	{
		dst = &__fb_ctx.null_desc;
	}

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* ------------------------------------------------------- mixed concatenation
**
** "narrow + ustring" and "ustring + narrow". The narrow operand is decoded and
** the result is a ustring, so text never silently degrades to bytes.
*/

FBCALL FBUSTRING *fb_UStrConcatAU
	(
		FBUSTRING *dst,
		void *str1,
		ssize_t str1_size,
		void *str2,
		ssize_t str2_size
	)
{
	const char *a_ptr;
	const FB_UCHAR *u_ptr;
	ssize_t a_len, u_len, a_units;

	FB_STRLOCK();

	FB_STRSETUP_FIX( str1, str1_size, a_ptr, a_len );
	FB_USTRSETUP( str2, str2_size, u_ptr, u_len );

	a_units = fb_hUtf8ToUtf16( a_ptr, a_len, NULL, 0 );

	dst = fb_hUStrAllocTemp_NoLock( dst, a_units + u_len );

	if( dst != NULL && dst->data != NULL )
	{
		fb_hUtf8ToUtf16( a_ptr, a_len, dst->data, a_units );
		/* NOT the terminating form: the tail follows */
		fb_hUStrCopy( dst->data + a_units, u_ptr, u_len );
	}

	if( str1_size == FB_STRSIZEVARLEN )
		fb_hStrDelTemp_NoLock( (FBSTRING *)str1 );
	if( str2_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)str2 );

	FB_STRUNLOCK();

	return dst;
}

FBCALL FBUSTRING *fb_UStrConcatUA
	(
		FBUSTRING *dst,
		void *str1,
		ssize_t str1_size,
		void *str2,
		ssize_t str2_size
	)
{
	const FB_UCHAR *u_ptr;
	const char *a_ptr;
	ssize_t u_len, a_len, a_units;

	FB_STRLOCK();

	FB_USTRSETUP( str1, str1_size, u_ptr, u_len );
	FB_STRSETUP_FIX( str2, str2_size, a_ptr, a_len );

	a_units = fb_hUtf8ToUtf16( a_ptr, a_len, NULL, 0 );

	dst = fb_hUStrAllocTemp_NoLock( dst, u_len + a_units );

	if( dst != NULL && dst->data != NULL )
	{
		fb_hUStrCopyN( dst->data, u_ptr, u_len );
		fb_hUtf8ToUtf16( a_ptr, a_len, dst->data + u_len, a_units );
		dst->data[u_len + a_units] = 0;
	}

	if( str1_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)str1 );
	if( str2_size == FB_STRSIZEVARLEN )
		fb_hStrDelTemp_NoLock( (FBSTRING *)str2 );

	FB_STRUNLOCK();

	return dst;
}
