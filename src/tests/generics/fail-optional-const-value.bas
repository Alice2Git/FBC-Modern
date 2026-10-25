' TEST_MODE : COMPILE_ONLY_FAIL

'' Value( ) is not a const method: it returns BYREF T, a writable reference to
'' the stored value.  On a const Optional it is refused (error 276) -- read the
'' value with ValueOr( ) there.  optional-const.bas has what does work.

#include once "fb/optional.bi"

sub Show( byref o as const FB.Optional( of long ) )
	print o.Value( )
end sub
