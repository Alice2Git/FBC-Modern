/* ustring <-> wstring conversion
**
** THE ASYMMETRY THIS FILE EXISTS FOR
**
** A ustring code unit is 16 bits on every target. FB_WCHAR is wchar_t: 16 bits
** on Windows, 32 on Linux, 8 on DOS. So:
**
**   Windows  ustring and wstring are the same representation. Copying is a
**            memcpy, and at the call boundary the compiler can hand out the
**            buffer pointer directly with no conversion at all.
**   Linux    every character has to be re-encoded, UTF-16 <-> UTF-32, into a
**            fresh buffer.
**   DOS      FB_WCHAR is char (DISABLE_WCHAR); treated as Latin-1, which is the
**            most that target can represent.
**
** The branches below are on sizeof(FB_WCHAR) and fold away at compile time.
** They are NOT #ifdefs on the platform: the width is the thing that matters,
** and stating it that way keeps the three cases visible together.
*/

#include "fb.h"

/* The two width-dependent helpers live in a header so they can be compiled at
   all THREE wchar widths by tests/ustr_wchar_test.c. On this target two of the
   three branches are dead code, and dead code is untested code -- see the note
   at the top of that header. */
#include "ustr_wchar_conv.h"

/* --------------------------------------------------------------- assignment */

FBCALL void *fb_UStrAssignFromW
	(
		void *dst,
		ssize_t dst_size,
		const FB_WCHAR *src,
		int fill_rem,
		int is_init
	)
{
	ssize_t src_chars, units;
	FB_UCHAR *tmp;

	if( dst == NULL )
		return dst;

	src_chars = (src != NULL) ? (ssize_t)fb_wstr_Len( src ) : 0;

	units = hWcharToUnits( src, src_chars, NULL, 0 );

	tmp = (FB_UCHAR *)malloc( (units + 1) * sizeof( FB_UCHAR ) );
	if( tmp == NULL )
		return dst;

	hWcharToUnits( src, src_chars, tmp, units );

	fb_UStrAssignEx( dst, dst_size, tmp, (units | FB_STRISFIXED), fill_rem, is_init );

	free( tmp );

	return dst;
}

FBCALL FB_WCHAR *fb_UStrAssignToW
	(
		FB_WCHAR *dst,
		ssize_t dst_chars,
		void *src,
		ssize_t src_size
	)
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, n;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( dst != NULL )
	{
		/* dst_chars is the declared capacity INCLUDING the terminator, matching
		   how the compiler passes WSTRING * N lengths */
		ssize_t cap = (dst_chars > 0) ? (dst_chars - 1) : src_len;
		n = hUnitsToWchar( src_ptr, src_len, dst, cap );
		(void)n;
	}

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}

/* -------------------------------------------------- expression conversions */

FBCALL FBUSTRING *fb_WstrToUStr( const FB_WCHAR *src )
{
	FBUSTRING *dst;
	ssize_t src_chars, units;

	FB_STRLOCK();

	src_chars = (src != NULL) ? (ssize_t)fb_wstr_Len( src ) : 0;
	units = hWcharToUnits( src, src_chars, NULL, 0 );

	dst = fb_hUStrAllocTemp_NoLock( NULL, units );
	if( dst != NULL )
	{
		if( dst->data != NULL )
			hWcharToUnits( src, src_chars, dst->data, units );
	}
	else
	{
		dst = &__fb_ctx.unull_desc;
	}

	FB_STRUNLOCK();

	return dst;
}

/* ustring -> a freshly allocated wchar buffer.
**
** The caller frees it with fb_WstrDelete(), matching every other wstring-
** returning rtlib function. On Windows this still allocates -- the compiler
** avoids calling this at all where it can hand out the buffer directly. */
FBCALL FB_WCHAR *fb_UStrToWstr( void *src, ssize_t src_size )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, chars;
	FB_WCHAR *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	chars = hUnitsToWchar( src_ptr, src_len, NULL, 0 );

	dst = (FB_WCHAR *)malloc( (chars + 1) * sizeof( FB_WCHAR ) );
	if( dst != NULL )
		hUnitsToWchar( src_ptr, src_len, dst, chars );

	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );

	FB_STRUNLOCK();

	return dst;
}
