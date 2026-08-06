' TEST_MODE : COMPILE_ONLY_FAIL

'' The same contract for Set: an element type needs HashOf and '='.

#include once "fb/set.bi"
using FB

type NoHash
	as long a
end type

operator = ( byref x as NoHash, byref y as NoHash ) as boolean
	return x.a = y.a
end operator

dim s as Set( of NoHash )
