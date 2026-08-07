' TEST_MODE : COMPILE_ONLY_FAIL

'' Inference must refuse 'Max( v + v, v )'.
''
'' It looks like the same variable twice, which is exactly why this is pinned:
'' FreeBASIC promotes 'long + long' to the native INTEGER, so the two arguments
'' really are INTEGER and LONG.  RFC-0001 5 says inference never silently picks
'' between two types the author wrote, so this has to fail and ask for explicit
'' type arguments -- 'Max( of long )( v + v, v )' compiles fine.
''
'' Measured rather than assumed: the argument dtypes are 8 (FB_DATATYPE_INTEGER)
'' and 11 (FB_DATATYPE_LONG).  Two plausible-sounding theories about a compiler
'' bug died here first.

function Max( of T )( byval a as T, byval b as T ) as T
	if a > b then return a
	return b
end function

dim as long v = 21
print Max( v + v, v )
