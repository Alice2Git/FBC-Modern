/* ustring codecs -- UTF-8 / UTF-16 / UTF-32
**
** WHY NOT utf_conv*.c
**
** The existing converters are wchar_t-shaped (so their output width changes per
** target), mostly file-local statics, little-endian-only, and they have no
** replacement-character policy -- malformed input is decoded without complaint.
** A portable string type needs the opposite of all four properties, so these are
** written fresh.
**
** REPLACEMENT POLICY
**
** Every malformed sequence and every lone surrogate becomes exactly one U+FFFD.
** Nothing raises an error. A text editor must be able to open a damaged file,
** not refuse it. Malformed sequences consume their "maximal subpart" (the lead
** byte plus any continuation bytes that were individually well-formed), so one
** damaged character yields one U+FFFD rather than one per byte -- this is the
** Unicode-recommended practice, and it keeps offsets sane.
**
** CAPACITY CONTRACT
**
** Every converter writes at most dst_units (resp. dst_bytes) elements of
** content, then NUL-terminates -- so the destination must hold one MORE element
** than the capacity passed. That matches fb_hUStrAlloc, which always allocates
** units+1. The return value is the count that WOULD have been written, so
** passing dst == NULL measures exactly, and a short buffer is detectable rather
** than silent.
*/

#include "fb.h"

#define UEMIT(u) do { if( (dst != NULL) && (n < dst_units) ) dst[n] = (FB_UCHAR)(u); ++n; } while(0)
#define BEMIT(b) do { if( (dst != NULL) && (n < dst_bytes) ) dst[n] = (char)(b);     ++n; } while(0)

/* Emit a scalar value as UTF-16: one unit inside the BMP, a surrogate pair
   above it. Callers have already rejected surrogates and out-of-range values. */
#define UEMIT_CP(cp)                                    \
do {                                                    \
	if( (cp) < 0x10000u )                               \
	{                                                   \
		UEMIT( cp );                                    \
	}                                                   \
	else                                                \
	{                                                   \
		UEMIT( FB_UCHAR_CP_HIGHSUR( cp ) );             \
		UEMIT( FB_UCHAR_CP_LOWSUR( cp ) );              \
	}                                                   \
} while (0)

#define IS_CONT(b) (((b) & 0xC0) == 0x80)


ssize_t fb_hUtf8ToUtf16( const char *src, ssize_t src_bytes,
                         FB_UCHAR *dst, ssize_t dst_units )
{
	const unsigned char *s = (const unsigned char *)src;
	ssize_t i = 0, n = 0;

	if( src == NULL )
		src_bytes = 0;

	while( i < src_bytes )
	{
		unsigned int b0 = s[i];
		uint32_t cp;

		/* 1 byte: U+0000..U+007F -- the overwhelmingly common case */
		if( b0 < 0x80 )
		{
			UEMIT( b0 );
			i += 1;
			continue;
		}

		/* 0x80..0xBF is a stray continuation; 0xC0/0xC1 would always be
		   overlong; 0xF5..0xFF would always exceed U+10FFFF. */
		if( (b0 < 0xC2) || (b0 > 0xF4) )
		{
			UEMIT( FB_UCHAR_REPLACEMENT );
			i += 1;
			continue;
		}

		/* 2 bytes: U+0080..U+07FF */
		if( b0 < 0xE0 )
		{
			if( (i + 1 >= src_bytes) || !IS_CONT( s[i+1] ) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 1;
				continue;
			}
			cp = ((uint32_t)(b0 & 0x1F) << 6) | (uint32_t)(s[i+1] & 0x3F);
			UEMIT( cp );
			i += 2;
			continue;
		}

		/* 3 bytes: U+0800..U+FFFF. The second-byte range is narrowed per lead
		   so that overlong forms (E0 80..9F) and the surrogate block
		   (ED A0..BF) are rejected here rather than after decoding. */
		if( b0 < 0xF0 )
		{
			unsigned int lo2 = 0x80, hi2 = 0xBF;
			if( b0 == 0xE0 )      lo2 = 0xA0;
			else if( b0 == 0xED ) hi2 = 0x9F;

			if( (i + 1 >= src_bytes) || (s[i+1] < lo2) || (s[i+1] > hi2) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 1;
				continue;
			}
			if( (i + 2 >= src_bytes) || !IS_CONT( s[i+2] ) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 2;          /* maximal subpart: lead + the good second byte */
				continue;
			}
			cp = ((uint32_t)(b0 & 0x0F) << 12)
			   | ((uint32_t)(s[i+1] & 0x3F) << 6)
			   |  (uint32_t)(s[i+2] & 0x3F);
			UEMIT( cp );
			i += 3;
			continue;
		}

		/* 4 bytes: U+10000..U+10FFFF. Again the second-byte range is narrowed
		   per lead: F0 90..BF excludes overlongs, F4 80..8F excludes > U+10FFFF. */
		{
			unsigned int lo2 = 0x80, hi2 = 0xBF;
			if( b0 == 0xF0 )      lo2 = 0x90;
			else if( b0 == 0xF4 ) hi2 = 0x8F;

			if( (i + 1 >= src_bytes) || (s[i+1] < lo2) || (s[i+1] > hi2) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 1;
				continue;
			}
			if( (i + 2 >= src_bytes) || !IS_CONT( s[i+2] ) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 2;
				continue;
			}
			if( (i + 3 >= src_bytes) || !IS_CONT( s[i+3] ) )
			{
				UEMIT( FB_UCHAR_REPLACEMENT );
				i += 3;
				continue;
			}
			cp = ((uint32_t)(b0 & 0x07) << 18)
			   | ((uint32_t)(s[i+1] & 0x3F) << 12)
			   | ((uint32_t)(s[i+2] & 0x3F) << 6)
			   |  (uint32_t)(s[i+3] & 0x3F);
			UEMIT_CP( cp );
			i += 4;
		}
	}

	if( dst != NULL )
		dst[(n < dst_units) ? n : dst_units] = 0;

	return n;
}


ssize_t fb_hUtf16ToUtf8( const FB_UCHAR *src, ssize_t src_units,
                         char *dst, ssize_t dst_bytes )
{
	ssize_t i = 0, n = 0;

	if( src == NULL )
		src_units = 0;

	while( i < src_units )
	{
		uint32_t cp = src[i];

		if( FB_UCHAR_IS_HIGHSUR( cp ) )
		{
			if( (i + 1 < src_units) && FB_UCHAR_IS_LOWSUR( src[i+1] ) )
			{
				cp = FB_UCHAR_SURPAIR_CP( src[i], src[i+1] );
				i += 2;
			}
			else
			{
				/* unpaired high surrogate */
				cp = FB_UCHAR_REPLACEMENT;
				i += 1;
			}
		}
		else if( FB_UCHAR_IS_LOWSUR( cp ) )
		{
			/* low surrogate with no high before it */
			cp = FB_UCHAR_REPLACEMENT;
			i += 1;
		}
		else
		{
			i += 1;
		}

		if( cp < 0x80u )
		{
			BEMIT( cp );
		}
		else if( cp < 0x800u )
		{
			BEMIT( 0xC0u | (cp >> 6) );
			BEMIT( 0x80u | (cp & 0x3Fu) );
		}
		else if( cp < 0x10000u )
		{
			BEMIT( 0xE0u | (cp >> 12) );
			BEMIT( 0x80u | ((cp >> 6) & 0x3Fu) );
			BEMIT( 0x80u | (cp & 0x3Fu) );
		}
		else
		{
			BEMIT( 0xF0u | (cp >> 18) );
			BEMIT( 0x80u | ((cp >> 12) & 0x3Fu) );
			BEMIT( 0x80u | ((cp >> 6) & 0x3Fu) );
			BEMIT( 0x80u | (cp & 0x3Fu) );
		}
	}

	if( dst != NULL )
		dst[(n < dst_bytes) ? n : dst_bytes] = 0;

	return n;
}


/* UTF-32 -> UTF-16. This is the Linux half of WSTRING interop: there a wstring
   is 4 bytes per character, so feeding one to a ustring lands here. On Windows
   wstring is already UTF-16 and no conversion is needed at all. */
ssize_t fb_hUtf32ToUtf16( const uint32_t *src, ssize_t src_units,
                          FB_UCHAR *dst, ssize_t dst_units )
{
	ssize_t i, n = 0;

	if( src == NULL )
		src_units = 0;

	for( i = 0; i < src_units; i++ )
	{
		uint32_t cp = src[i];

		/* lone surrogates and out-of-range values are not scalar values */
		if( (cp > FB_UCHAR_MAX_CP) || FB_UCHAR_IS_SUR( cp ) )
			cp = FB_UCHAR_REPLACEMENT;

		UEMIT_CP( cp );
	}

	if( dst != NULL )
		dst[(n < dst_units) ? n : dst_units] = 0;

	return n;
}


/* UTF-16 -> UTF-32, the other half of the Linux WSTRING interop. */
ssize_t fb_hUtf16ToUtf32( const FB_UCHAR *src, ssize_t src_units,
                          uint32_t *dst, ssize_t dst_units )
{
	ssize_t i = 0, n = 0;

	if( src == NULL )
		src_units = 0;

	while( i < src_units )
	{
		ssize_t used;
		uint32_t cp = fb_hUStrCodepointAt( src, src_units, i, &used );

		if( (dst != NULL) && (n < dst_units) )
			dst[n] = cp;
		++n;
		i += used;
	}

	if( dst != NULL )
		dst[(n < dst_units) ? n : dst_units] = 0;

	return n;
}


/* Decode one scalar value. A well-formed surrogate pair consumes 2 units; a
   lone surrogate yields U+FFFD and consumes 1, so callers can always advance
   and never loop forever on damaged input. */
uint32_t fb_hUStrCodepointAt( const FB_UCHAR *src, ssize_t len,
                              ssize_t i, ssize_t *units_used )
{
	ssize_t used = 1;
	uint32_t cp;

	if( (src == NULL) || (i < 0) || (i >= len) )
	{
		if( units_used != NULL )
			*units_used = 1;
		return 0;
	}

	cp = src[i];

	if( FB_UCHAR_IS_HIGHSUR( cp ) )
	{
		if( (i + 1 < len) && FB_UCHAR_IS_LOWSUR( src[i+1] ) )
		{
			cp = FB_UCHAR_SURPAIR_CP( src[i], src[i+1] );
			used = 2;
		}
		else
		{
			cp = FB_UCHAR_REPLACEMENT;
		}
	}
	else if( FB_UCHAR_IS_LOWSUR( cp ) )
	{
		cp = FB_UCHAR_REPLACEMENT;
	}

	if( units_used != NULL )
		*units_used = used;

	return cp;
}
