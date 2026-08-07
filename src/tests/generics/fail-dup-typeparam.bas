' TEST_MODE : COMPILE_ONLY_FAIL
/'
	Two type parameters with the same name.
'/
type Box( of T, T )
	as T v
end type
