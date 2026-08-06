' TEST_MODE : COMPILE_ONLY_FAIL

'' Sort requires '<' on the element type.
''
'' The requirement lands HERE, at the call, and not on Array itself -- which is
'' the whole reason Sort is a free generic procedure rather than a member.  An
'' Array of this type is perfectly usable; only sorting it is not.

#include once "fb/array.bi"
using FB

type NoLess
	as long a
end type

dim v as Array( of NoLess )
dim as NoLess x
v.Push( x )
v.Push( x )

Sort( v )
