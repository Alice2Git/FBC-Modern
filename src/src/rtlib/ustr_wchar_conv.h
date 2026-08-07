/* wstring <-> ustring code-unit conversion, parameterised by wchar width.
**
** WHY THIS IS A HEADER AND NOT JUST TWO STATIC FUNCTIONS IN ustr_convw.c
**
** The three branches below are selected by sizeof(FB_WCHAR) and fold away at
** compile time. That means on Windows, where FB_WCHAR is 16 bits, the UTF-32
** and 8-bit branches are DEAD CODE -- never compiled into anything runnable,
** never executed, and so never tested. They are exactly the code that has to be
** right on Linux and DOS, and exactly the code no Windows developer can check.
**
** Putting them here lets tests/ustr_wchar_test.c include this file three times,
** once per width, and run all three branches natively. The test therefore
** exercises THIS source rather than a copy of it, which is the only way the
** result means anything.
**
** There is deliberately NO include guard: repeated inclusion is the point. The
** parameter macros are #undef'd at the end so each inclusion starts clean.
*/

#ifndef UWCONV_WCHAR
#define UWCONV_WCHAR FB_WCHAR
#endif
#ifndef UWCONV_TOUNITS
#define UWCONV_TOUNITS hWcharToUnits
#endif
#ifndef UWCONV_TOWCHAR
#define UWCONV_TOWCHAR hUnitsToWchar
#endif

/* wstring -> ustring, into a caller-provided buffer sized by the measure pass.
   Returns units written (excluding the terminator); dst may be NULL to measure. */
static ssize_t UWCONV_TOUNITS( const UWCONV_WCHAR *src, ssize_t src_chars,
                               FB_UCHAR *dst, ssize_t dst_units )
{
	if( sizeof( UWCONV_WCHAR ) == 2 )
	{
		/* already UTF-16, including any surrogate pairs */
		ssize_t n = src_chars;
		if( dst != NULL )
		{
			ssize_t i, lim = (n < dst_units) ? n : dst_units;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_UCHAR)src[i];
			dst[lim] = 0;
		}
		return n;
	}
	else if( sizeof( UWCONV_WCHAR ) == 4 )
	{
		/* UTF-32 -> UTF-16; a scalar above the BMP becomes a surrogate pair,
		   so the unit count is NOT the character count */
		ssize_t i, n = 0;
		for( i = 0; i < src_chars; i++ )
		{
			uint32_t cp = (uint32_t)src[i];
			if( (cp > FB_UCHAR_MAX_CP) || FB_UCHAR_IS_SUR( cp ) )
				cp = FB_UCHAR_REPLACEMENT;

			if( cp < 0x10000u )
			{
				if( (dst != NULL) && (n < dst_units) ) dst[n] = (FB_UCHAR)cp;
				n++;
			}
			else
			{
				if( (dst != NULL) && (n < dst_units) ) dst[n] = FB_UCHAR_CP_HIGHSUR( cp );
				n++;
				if( (dst != NULL) && (n < dst_units) ) dst[n] = FB_UCHAR_CP_LOWSUR( cp );
				n++;
			}
		}
		if( dst != NULL )
			dst[(n < dst_units) ? n : dst_units] = 0;
		return n;
	}
	else
	{
		/* DOS: FB_WCHAR is char. Latin-1 is the best this target can do. */
		ssize_t i, n = src_chars;
		if( dst != NULL )
		{
			ssize_t lim = (n < dst_units) ? n : dst_units;
			for( i = 0; i < lim; i++ )
				dst[i] = (FB_UCHAR)(unsigned char)src[i];
			dst[lim] = 0;
		}
		return n;
	}
}

/* ustring -> wstring. Returns chars written (excluding the terminator). */
static ssize_t UWCONV_TOWCHAR( const FB_UCHAR *src, ssize_t src_units,
                               UWCONV_WCHAR *dst, ssize_t dst_chars )
{
	if( sizeof( UWCONV_WCHAR ) == 2 )
	{
		ssize_t n = src_units;
		if( dst != NULL )
		{
			ssize_t i, lim = (n < dst_chars) ? n : dst_chars;
			for( i = 0; i < lim; i++ )
				dst[i] = (UWCONV_WCHAR)src[i];
			dst[lim] = 0;
		}
		return n;
	}
	else if( sizeof( UWCONV_WCHAR ) == 4 )
	{
		/* UTF-16 -> UTF-32: a surrogate pair collapses into one char */
		ssize_t i = 0, n = 0;
		while( i < src_units )
		{
			ssize_t used;
			uint32_t cp = fb_hUStrCodepointAt( src, src_units, i, &used );
			if( (dst != NULL) && (n < dst_chars) ) dst[n] = (UWCONV_WCHAR)cp;
			n++;
			i += used;
		}
		if( dst != NULL )
			dst[(n < dst_chars) ? n : dst_chars] = 0;
		return n;
	}
	else
	{
		/* DOS: anything outside Latin-1 cannot be represented */
		ssize_t i, n = src_units;
		if( dst != NULL )
		{
			ssize_t lim = (n < dst_chars) ? n : dst_chars;
			for( i = 0; i < lim; i++ )
				dst[i] = (UWCONV_WCHAR)((src[i] < 256) ? src[i] : '?');
			dst[lim] = 0;
		}
		return n;
	}
}

#undef UWCONV_WCHAR
#undef UWCONV_TOUNITS
#undef UWCONV_TOWCHAR
