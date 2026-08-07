/* ustring LEN
**
** Returns CODE UNITS, not characters and not bytes. An astral character is a
** surrogate pair and therefore counts as 2 -- the same answer WSTRING already
** gives on Windows. Counting codepoints instead would make LEN O(n) and would
** silently disagree with [] indexing, which is O(1) and unit-based.
*/

#include "fb.h"

FBCALL ssize_t fb_UStrLen( void *str, ssize_t str_size )
{
	const FB_UCHAR *ptr;
	ssize_t len;

	FB_USTRSETUP( str, str_size, ptr, len );
	(void)ptr;   /* the macro yields both; only the length is wanted here */

	/* a temp operand (e.g. LEN(a + b)) is ours to release */
	if( str_size == FB_USTRSIZEVARLEN )
	{
		FB_STRLOCK();
		fb_hUStrDelTemp_NoLock( (FBUSTRING *)str );
		FB_STRUNLOCK();
	}

	return len;
}
