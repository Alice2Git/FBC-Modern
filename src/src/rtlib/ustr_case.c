/* ustring case conversion: UCASE, LCASE
**
** Uses the generated table in ustr_casetable.c, NOT towupper()/towlower().
** Those are locale-dependent, so the same ustring would fold differently
** depending on the user's locale and on which libc the program linked against
** -- the exact platform divergence this type exists to remove.
**
** Simple case mapping only: one code unit in, one out. Case changes that alter
** length (German sharp s upper-casing to "SS") are not applied, matching what
** every other FB string type does and what an in-place unit transform can
** express.
*/

#include "fb.h"

static void hUStrRelTemp( void *src, ssize_t src_size )
{
	if( src_size == FB_USTRSIZEVARLEN )
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)src );
}

static FBUSTRING *hUStrCase( void *src, ssize_t src_size, int toupper )
{
	const FB_UCHAR *src_ptr;
	ssize_t src_len, i;
	FBUSTRING *dst;

	FB_USTRSETUP( src, src_size, src_ptr, src_len );

	if( src_len <= 0 )
		return &__fb_ctx.unull_desc;

	dst = fb_hUStrAllocTemp_NoLock( NULL, src_len );
	if( dst == NULL )
		return &__fb_ctx.unull_desc;

	if( dst->data != NULL )
	{
		for( i = 0; i < src_len; i++ )
		{
			if( toupper )
				dst->data[i] = fb_hUStrToUpper( src_ptr[i] );
			else
				dst->data[i] = fb_hUStrToLower( src_ptr[i] );
		}
		dst->data[src_len] = 0;
	}

	return dst;
}

FBCALL FBUSTRING *fb_UStrUcase( void *src, ssize_t src_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrCase( src, src_size, 1 );
	hUStrRelTemp( src, src_size );
	FB_STRUNLOCK();
	return dst;
}

FBCALL FBUSTRING *fb_UStrLcase( void *src, ssize_t src_size )
{
	FBUSTRING *dst;
	FB_STRLOCK();
	dst = hUStrCase( src, src_size, 0 );
	hUStrRelTemp( src, src_size );
	FB_STRUNLOCK();
	return dst;
}
