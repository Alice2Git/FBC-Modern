/* ustring slicing: LEFT, RIGHT, MID (function and statement), SPACE, STRING
**
** POSITIONS AND LENGTHS ARE IN CODE UNITS, and 1-based as everywhere in FB.
**
** Code units, not characters: consistent with LEN() and with [] indexing, both
** of which are O(1) and unit-based. The consequence is that MID() can split a
** surrogate pair, exactly as it can on WSTRING today -- slicing blind to
** encoding is a property of UTF-16, not something this type introduces. Callers
** that need character boundaries walk them with the codepoint helpers.
*/

#include "fb.h"

/* Allocate a temp descriptor and fill it from src[0..units-1]. */
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

/* Release the source if it was itself a temp. Every entry point below has to do
   this or an expression like LEFT(a + b, 2) leaks a pool slot. */
static void hUStrRelTemp( void *src, ssize_t src_size )
{
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
}

FBCALL FBUSTRING *fb_UStrLeft( void *src, ssize_t src_size, ssize_t units )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len;
	FBUSTRING *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( units > src_len )
		units = src_len;

	dst = hUStrTempFrom( src_ptr, units );

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();

	return dst;
}

FBCALL FBUSTRING *fb_UStrRight( void *src, ssize_t src_size, ssize_t units )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len;
	FBUSTRING *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( units > src_len )
		units = src_len;

	if( units <= 0 )
		dst = &__fb_ctx.unull_desc;
	else
		dst = hUStrTempFrom( &src_ptr[src_len - units], units );

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();

	return dst;
}

/* MID( s, start [, units] ). start is 1-based; a negative unit count means
   "to the end", matching fb_WstrMid(). */
FBCALL FBUSTRING *fb_UStrMid( void *src, ssize_t src_size, ssize_t start, ssize_t units )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len;
	FBUSTRING *dst;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( (src_len == 0) || (start <= 0) || (start > src_len) || (units == 0) )
	{
		dst = &__fb_ctx.unull_desc;
	}
	else
	{
		--start;

		if( units < 0 )
			units = src_len;

		if( start + units > src_len )
			units = src_len - start;

		dst = hUStrTempFrom( &src_ptr[start], units );
	}

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();

	return dst;
}

/* MID( dst, start [, units] ) = src -- overwrites in place, never resizes dst.
   That is FB's MID statement semantics, shared by every string type. */
FBCALL void fb_UStrAssignMid
	(
		void *dst,
		ssize_t dst_size,
		ssize_t start,
		ssize_t units,
		void *src,
		ssize_t src_size
	)
{
	FB_UCHAR *dst_ptr;
	const FB_UCHAR *src_ptr;
	ssize_t dst_len, src_len;

	FB_STRLOCK();

	FB_USTRSETUP( dst, dst_size, dst_ptr, dst_len );
	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( (dst_ptr != NULL) && (start > 0) && (start <= dst_len) )
	{
		--start;

		/* clamp to what is actually there: the statement form never grows */
		if( (units < 0) || (units > src_len) )
			units = src_len;

		if( start + units > dst_len )
			units = dst_len - start;

		if( units > 0 )
			fb_hUStrCopyN( &dst_ptr[start], src_ptr, units );
	}

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();
}

/* SPACE( n ) */
FBCALL FBUSTRING *fb_UStrSpace( ssize_t units )
{
	FBUSTRING *dst;

	FB_STRLOCK();

	if( units <= 0 )
	{
		dst = &__fb_ctx.unull_desc;
	}
	else
	{
		dst = fb_hUStrAllocTemp_NoLock( NULL, units );
		if( dst == NULL )
		{
			dst = &__fb_ctx.unull_desc;
		}
		else if( dst->data != NULL )
		{
			fb_hUStrFill( dst->data, (FB_UCHAR)' ', units );
			dst->data[units] = 0;
		}
	}

	FB_STRUNLOCK();

	return dst;
}

/* STRING( n, code_unit ) */
FBCALL FBUSTRING *fb_UStrFill1( ssize_t units, int unit )
{
	FBUSTRING *dst;

	FB_STRLOCK();

	if( units <= 0 )
	{
		dst = &__fb_ctx.unull_desc;
	}
	else
	{
		dst = fb_hUStrAllocTemp_NoLock( NULL, units );
		if( dst == NULL )
		{
			dst = &__fb_ctx.unull_desc;
		}
		else if( dst->data != NULL )
		{
			fb_hUStrFill( dst->data, (FB_UCHAR)unit, units );
			dst->data[units] = 0;
		}
	}

	FB_STRUNLOCK();

	return dst;
}

/* STRING( n, s ) -- repeats the FIRST code unit of s, as the narrow form
   repeats the first character. */
FBCALL FBUSTRING *fb_UStrFill2( ssize_t units, void *src, ssize_t src_size )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len;
	FBUSTRING *dst;
	FB_UCHAR c;

	FB_STRLOCK();

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	c = (src_len > 0) ? src_ptr[0] : (FB_UCHAR)' ';

	if( units <= 0 )
	{
		dst = &__fb_ctx.unull_desc;
	}
	else
	{
		dst = fb_hUStrAllocTemp_NoLock( NULL, units );
		if( dst == NULL )
		{
			dst = &__fb_ctx.unull_desc;
		}
		else if( dst->data != NULL )
		{
			fb_hUStrFill( dst->data, c, units );
			dst->data[units] = 0;
		}
	}

	hUStrRelTemp( src, src_size );

	FB_STRUNLOCK();

	return dst;
}

/* ------------------------------------------------- overload entry points
**
** LEFT and RIGHT are registered as true OVERLOADS (rtl-string.bas), aliased
** straight to a C function, so their signature is fixed at two parameters and
** cannot carry the (ptr,size) pair the rest of the ustring API uses. These
** wrappers take a descriptor directly; a USTRING * N argument is converted to a
** temp descriptor by the argument handling before it gets here.
*/

FBCALL FBUSTRING *fb_UStrLeftD( FBUSTRING *src, ssize_t units )
{
	return fb_UStrLeft( src, FB_USTRSIZEVARLEN, units );
}

FBCALL FBUSTRING *fb_UStrRightD( FBUSTRING *src, ssize_t units )
{
	return fb_UStrRight( src, FB_USTRSIZEVARLEN, units );
}
