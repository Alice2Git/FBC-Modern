' TEST_MODE : COMPILE_ONLY_FAIL

'' IndexOf requires '=' on the element type, and again only at the call.

#include once "fb/array.bi"
using FB

type NoEq
	as long a
end type

dim v as Array( of NoEq )
dim as NoEq x
v.Push( x )

print IndexOf( v, x )
