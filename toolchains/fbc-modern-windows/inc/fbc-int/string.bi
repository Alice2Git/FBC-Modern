#ifndef __FBC_INT_STRING_BI__
#define __FBC_INT_STRING_BI__

# if __FB_LANG__ = "qb"
# error not supported in qb dialect
# endif

'' DISCLAIMER!!!
''
''   1) this header documents runtime library internals and is
''      subject to change without notice
''
'' declarations must follow ./src/rtlib/fb_string.h

'' fbc won't allow redefinition of these functions in to a namespace due to the
'' internal name lookups and caching in the rtlLookupTB() table - so instead we
'' can keep the global ones and also define our own in a namespace.  The global
'' ones will override the ones in our namespace unless we explicitly specify
'' the namespace
''
'' #undef fb_StrDelete
''

namespace FBC

extern "rtlib"

	type FB_CHAR as ZSTRING
	type FB_WCHAR as WSTRING

	'' var-len string descriptor
	type FBSTRING
		data as FB_CHAR ptr          '' pointer to the start of characters
		len as integer               '' length
		size as integer              '' size of allocated memory
	end type

	'' var-len wstring descriptor (future)
	type FBWSTRING
		data as FB_WCHAR ptr         '' pointer to the start of characters
		len as integer               '' length
		size as integer              '' size of allocated memory
	end type

	'' a USTRING code unit: uint16 on EVERY target, never wchar_t
	type FB_UCHAR as USHORT

	'' var-len ustring descriptor
	''
	'' NOTE: len and size are in CODE UNITS, not bytes. FBSTRING gets away with
	'' byte == char; here the two differ by a factor of 2.
	type FBUSTRING
		data as FB_UCHAR ptr         '' pointer to the start of code units
		len as integer               '' length, in code units
		size as integer              '' allocated code units
	end type

	'' VAR-LEN STRING API (FBSTRING)
	declare sub fb_StrDelete( byval s as const FBSTRING ptr )
	declare sub fb_LEFTSELF( byval dst as FBSTRING ptr, byval length as const integer )

	'' VAR-LEN STRING API (STRING)
	declare sub LEFTSELF alias "fb_LEFTSELF" ( byref dst as string, byval length as const integer )

end extern

end namespace

#endif
