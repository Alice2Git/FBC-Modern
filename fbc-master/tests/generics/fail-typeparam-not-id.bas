' TEST_MODE : COMPILE_ONLY_FAIL
/'
	A type parameter must be an identifier.
'/
type Box( of 42 )
	as integer v
end type
