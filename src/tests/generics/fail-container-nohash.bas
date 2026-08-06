' TEST_MODE : COMPILE_ONLY_FAIL

'' A key type with no HashOf overload cannot be a Map key.
''
'' This is the unconstrained-generics diagnostic RFC-0001 describes: the error
'' lands at the INSTANTIATION site and names HashOf, rather than at the
'' declaration.  It is the strongest single argument for adding constraints
'' later, and it is pinned here so the message cannot silently get worse.

#include once "fb/map.bi"
using FB

type NoHash
	as long a
end type

operator = ( byref x as NoHash, byref y as NoHash ) as boolean
	return x.a = y.a
end operator

dim m as Map( of NoHash, long )
