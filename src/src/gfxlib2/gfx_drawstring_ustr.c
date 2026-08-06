/* DRAW STRING for ustrings
**
** ONE CODE UNIT -> ONE GLYPH
**
** gfxlib2's font is a 256-glyph bitmap indexed by BYTE -- see gfx_drawstring.c,
** where the glyph lookup is literally char_data[(unsigned char)string->data[i]].
** There is no Unicode font support anywhere in gfxlib2, and the existing wide
** path says so out loud:
**
**     gfx_print_wstr.c:  "Unicode gfx font support is out of the scope of
**                         gfxlib, convert to ascii"
**
** So the only question a ustring raises is WHICH BYTE each character becomes.
**
** WHY NOT JUST LET IT CONVERT TO STRING
**
** It already did, and that was the bug. A ustring argument satisfied the
** narrow 'byref as const string' parameter through the normal UTF-8 conversion,
** so the call compiled and ran -- and drew two or three garbage glyphs for
** every non-ASCII character, because the font indexes bytes and UTF-8 spends
** several bytes per character. Worse, it was a REGRESSION against wstring,
** which at least converts one character to one byte.
**
** WHY CP437 AND NOT THE LOCALE
**
** gfxlib2 declares its own character set:
**
**     fb_gfx.h:  #define FB_GFX_GET_CHARSET() "CP437"
**
** and dumping the built-in 8x8 font agrees -- byte 0x01 is a smiley, 0xE9 is
** theta, 0xDB is a full block. So a table maps each code unit to its CP437
** byte, and characters the font has no glyph for become '?'.
**
** The wstring path instead calls fb_wstr_ConvToA, which goes through the C
** locale, so the same source draws different glyphs depending on the machine.
** A portable string type cannot behave that way, which is why this uses a
** fixed table even though it means diverging from the wstring precedent.
**
** A CUSTOM FONT is still indexed by byte, and its codepage is whatever the
** author's bitmap says it is -- unknowable from here. CP437 is a guess there,
** but a far better one than UTF-8 bytes. Anyone who needs exact control over a
** custom font's indices should pass a STRING, whose bytes go through untouched.
*/

#include "fb_gfx.h"
#include "gfx_cp437.h"

/* Code unit -> CP437 byte, or '?' when the font has no glyph for it.
**
** A linear scan of 256 entries, which is not worth optimising: it runs once per
** character and is followed by a blit of that character. ASCII short-circuits
** anyway, and that is nearly every call. */
static unsigned char hUnitToCp437( FB_UCHAR u )
{
	int b;

	/* the common case, and identity in CP437 */
	if( (u >= 0x20) && (u < 0x7F) )
		return (unsigned char)u;

	for( b = 0; b < 256; b++ )
		if( __fb_gfx_cp437_to_uni[b] == u )
			return (unsigned char)b;

	return (unsigned char)'?';
}

FBCALL int fb_GfxDrawStringUStr
	(
		void *target,
		float fx,
		float fy,
		int flags,
		FBUSTRING *string,
		unsigned int color,
		void *font,
		int mode,
		PUTTER *putter,
		BLENDER *blender,
		void *param
	)
{
	FBSTRING narrow;
	const FB_UCHAR *src;
	ssize_t len, i, n;
	unsigned char *buf;
	int res;

	if( (string == NULL) || (string->data == NULL) )
	{
		/* Hand the null case straight over, so a ustring reports exactly what a
		   string reports rather than inventing its own answer. */
		res = fb_GfxDrawString( target, fx, fy, flags,
		                        (string == NULL) ? NULL : (FBSTRING *)string,
		                        color, font, mode, putter, blender, param );
		fb_hUStrDelTemp( string );
		return res;
	}

	src = string->data;
	len = FB_USTRSIZE( string );

	buf = (unsigned char *)malloc( len + 1 );
	if( buf == NULL )
	{
		fb_hUStrDelTemp( string );
		return fb_ErrorSetNum( FB_RTERROR_OUTOFMEM );
	}

	n = 0;
	for( i = 0; i < len; i++ )
	{
		/* A surrogate pair is one character, so it must not become two '?'.
		   No astral character has a CP437 glyph, so the pair collapses to a
		   single substitute. */
		if( FB_UCHAR_IS_HIGHSUR( src[i] ) && (i + 1 < len) &&
		    FB_UCHAR_IS_LOWSUR( src[i + 1] ) )
		{
			buf[n++] = (unsigned char)'?';
			i++;
			continue;
		}

		buf[n++] = hUnitToCp437( src[i] );
	}
	buf[n] = '\0';

	/* A stack descriptor: not from the temp pool and no FB_TEMPSTRBIT in its
	   len, so fb_GfxDrawString will not try to free it. The buffer is ours. */
	narrow.data = (char *)buf;
	narrow.len  = n;
	narrow.size = n;

	res = fb_GfxDrawString( target, fx, fy, flags, &narrow, color, font, mode,
	                        putter, blender, param );

	free( buf );
	fb_hUStrDelTemp( string );

	return res;
}
