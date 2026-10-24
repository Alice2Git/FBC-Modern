' TEST_MODE : COMPILE_ONLY_FAIL

'' An omitted argument binds nothing, even when its parameter has a default:
'' 'Zero( )' leaves T with no argument to come from, so inference has to refuse
'' it -- error 340, explicit type arguments -- rather than guess T from the
'' default's '0'.

function Zero( of T )( byval x as T = 0 ) as T
	return x
end function

print Zero( )
