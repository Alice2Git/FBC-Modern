' TEST_MODE : COMPILE_ONLY_FAIL

'' 'function( ) as R' binds R to the result of a PROCEDURE POINTER argument.
'' A capturing lambda is a closure struct, not a procedure pointer, so the
'' argument does not fit the parameter and inference has to refuse it -- error
'' 340, explicit type arguments -- rather than bind R to anything.

function Run( of R )( byval fn as function( ) as R ) as R
	return fn( )
end function

dim as long k = 6
print Run( function[ byval k ]( ) as long : return k : end function )
