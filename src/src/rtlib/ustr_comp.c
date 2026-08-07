/* ustring comparison
**
** Ordering is by code unit (see fb_hUStrCompare in ustr_prim.c for the UTF-16
** ordering caveat this inherits). Returns <0, 0, >0 like fb_StrCompare, so the
** compiler can lower  a < b  to  fb_UStrCompare(a,b) < 0.
*/

#include "fb.h"

FBCALL int fb_UStrCompare( void *str1, ssize_t str1_size, void *str2, ssize_t str2_size )
{
	const FB_UCHAR *s1_ptr, *s2_ptr;
	ssize_t s1_len, s2_len;
	int res;

	FB_USTRSETUP( str1, str1_size, s1_ptr, s1_len );
	FB_USTRSETUP( str2, str2_size, s2_ptr, s2_len );

	res = fb_hUStrCompare( s1_ptr, s1_len, s2_ptr, s2_len );

	/* release temp operands -- comparing two concatenations must not leak */
	if( (str1_size == FB_USTRSIZEVARLEN) || (str2_size == FB_USTRSIZEVARLEN) )
	{
		FB_STRLOCK();
		if( str1_size == FB_USTRSIZEVARLEN )
			fb_hUStrDelTemp_NoLock( (FBUSTRING *)str1 );
		if( str2_size == FB_USTRSIZEVARLEN )
			fb_hUStrDelTemp_NoLock( (FBUSTRING *)str2 );
		FB_STRUNLOCK();
	}

	return res;
}
