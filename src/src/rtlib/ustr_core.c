/* ustring descriptor allocation, deletion and the temp-descriptor pool
**
** Direct port of str_core.c. The allocation policy is deliberately identical --
** round up, then grow by 12.5% -- because that is what keeps repeated appends
** amortised O(1). Building a long string one unit at a time with a
** grow-by-exactly-what-was-asked policy is quadratic.
**
** THE UNIT RULE: every 'units' parameter here, and both FBUSTRING::len and
** FBUSTRING::size, are in CODE UNITS. The sizeof(FB_UCHAR) multiply appears
** only in this file, in the three malloc/realloc calls. Nowhere else in the
** ustring implementation should it appear at all.
*/

#include "fb.h"
#include <stddef.h>

/**********
** temp ustring descriptors (the string lock is assumed held in the MT rtlib)
**********/

static FB_LIST utmpdsList = { 0, NULL, NULL, NULL };

static FB_USTR_TMPDESC fb_utmpdsTB[FB_STR_TMPDESCRIPTORS];

FBCALL FBUSTRING *fb_hUStrAllocTempDesc( void )
{
	FB_USTR_TMPDESC *dsc;

	if( (utmpdsList.fhead == NULL) && (utmpdsList.head == NULL) )
		fb_hListInit( &utmpdsList, fb_utmpdsTB,
		              sizeof(FB_USTR_TMPDESC), FB_STR_TMPDESCRIPTORS );

	dsc = (FB_USTR_TMPDESC *)fb_hListAllocElem( &utmpdsList );
	if( dsc == NULL )
		return NULL;

	dsc->desc.data = NULL;
	dsc->desc.len  = 0;
	dsc->desc.size = 0;

	return &dsc->desc;
}

static void fb_hUStrFreeTmpDesc( FB_USTR_TMPDESC *dsc )
{
	fb_hListFreeElem( &utmpdsList, &dsc->elem );

	dsc->desc.data = NULL;
	dsc->desc.len  = 0;
	dsc->desc.size = 0;
}

FBCALL int fb_hUStrDelTempDesc( FBUSTRING *str )
{
	FB_USTR_TMPDESC *item =
	    (FB_USTR_TMPDESC*) ( (char*)str - offsetof( FB_USTR_TMPDESC, desc ) );

	/* is this really a temp descriptor?
	   NOTE: this is a range check against OUR table only. A narrow FBSTRING
	   temp lives in str_core.c's table and must never be matched here, which
	   is why the two pools are separate static arrays rather than one. */
	if( (item < fb_utmpdsTB+0) ||
		(item > fb_utmpdsTB+FB_STR_TMPDESCRIPTORS-1) )
		return -1;

	fb_hUStrFreeTmpDesc( item );
	return 0;
}

/**********
** internal helper routines
**********/

/* Round up to 16 code units == 32 bytes, matching the 32-BYTE granularity of
   the narrow allocator (str_core.c rounds to 32 bytes, and there a byte is a
   char). Rounding to 32 *units* would silently double the granularity. */
#define hUStrRoundSize( units ) (((units) + 15) & ~15)

/* Guard against (units + 1) * sizeof(FB_UCHAR) overflowing ssize_t. */
#define hUStrTooBig( units ) \
	( (units) < 0 || (size_t)(units) > (((size_t)-1 >> 1) / sizeof(FB_UCHAR)) - 1 )

FBCALL void fb_UStrDelete( FBUSTRING *str )
{
	if( str == NULL )
		return;

	if( str->data != NULL )
		free( (void *)str->data );

	str->data = NULL;
	str->len  = 0;
	str->size = 0;
}

FBCALL FBUSTRING *fb_hUStrAlloc( FBUSTRING *str, ssize_t units )
{
	ssize_t newsize;

	if( hUStrTooBig( units ) )
	{
		str->data = NULL;
		str->len = str->size = 0;
		return NULL;
	}

	newsize = hUStrRoundSize( units );

	str->data = (FB_UCHAR *)malloc( (newsize + 1) * sizeof( FB_UCHAR ) );
	/* failed? try the original request */
	if( str->data == NULL )
	{
		str->data = (FB_UCHAR *)malloc( (units + 1) * sizeof( FB_UCHAR ) );
		if( str->data == NULL )
		{
			str->len = str->size = 0;
			return NULL;
		}

		newsize = units;
	}

	str->size = newsize;
	str->len = units;

	return str;
}

FBCALL FBUSTRING *fb_hUStrRealloc( FBUSTRING *str, ssize_t units, int preserve )
{
	ssize_t newsize;

	if( hUStrTooBig( units ) )
		return NULL;

	newsize = hUStrRoundSize( units );
	/* plus 12.5% more */
	newsize += (newsize >> 3);

	if( (str->data == NULL) ||
		(units > str->size) ||
		( !preserve && (newsize < (str->size - (str->size >> 3)))) )
	{
		if( preserve == FB_FALSE )
		{
			fb_UStrDelete( str );

			str->data = (FB_UCHAR *)malloc( (newsize + 1) * sizeof( FB_UCHAR ) );
			/* failed? try the original request */
			if( str->data == NULL )
			{
				str->data = (FB_UCHAR *)malloc( (units + 1) * sizeof( FB_UCHAR ) );
				newsize = units;
			}
		}
		else
		{
			FB_UCHAR *newbuffer;
			newbuffer = (FB_UCHAR *)realloc( str->data,
			                                 (newsize + 1) * sizeof( FB_UCHAR ) );

			/* failed? try the original request */
			if( newbuffer == NULL )
			{
				newsize = units;
				newbuffer = (FB_UCHAR *)realloc( str->data,
				                                 (newsize + 1) * sizeof( FB_UCHAR ) );
				if( newbuffer == NULL )
				{
					return NULL;
				}
			}
			str->data = newbuffer;
		}

		if( str->data == NULL )
		{
			str->len = str->size = 0;
			return NULL;
		}

		str->size = newsize;
	}

	fb_hUStrSetLength( str, units );

	return str;
}

FBCALL FBUSTRING *fb_hUStrAllocTemp_NoLock( FBUSTRING *str, ssize_t units )
{
	int try_alloc = str==NULL;

	if( try_alloc )
	{
		str = fb_hUStrAllocTempDesc( );
		if( str==NULL )
			return NULL;
	}

	if( fb_hUStrRealloc( str, units, FB_FALSE ) == NULL )
	{
		if( try_alloc )
			fb_hUStrDelTempDesc( str );
		return NULL;
	}
	else
		str->len |= FB_TEMPSTRBIT;

	return str;
}

FBCALL FBUSTRING *fb_hUStrAllocTemp( FBUSTRING *str, ssize_t units )
{
	FBUSTRING *res;

	FB_STRLOCK( );

	res = fb_hUStrAllocTemp_NoLock( str, units );

	FB_STRUNLOCK( );

	return res;
}

FBCALL int fb_hUStrDelTemp_NoLock( FBUSTRING *str )
{
	if( str == NULL )
		return -1;

	/* is it really a temp? */
	if( FB_UISTEMP( str ) )
		fb_UStrDelete( str );

	/* del descriptor (must be done last as it will be cleared) */
	return fb_hUStrDelTempDesc( str );
}

FBCALL int fb_hUStrDelTemp( FBUSTRING *str )
{
	int res;

	FB_STRLOCK( );

	res = fb_hUStrDelTemp_NoLock( str );

	FB_STRUNLOCK( );

	return res;
}
