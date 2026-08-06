' TEST_MODE : COMPILE_ONLY_FAIL
/'
	Box(of long) and Box(of double) are unrelated types; neither is assignable
	to the other.
'/
type Box( of T )
	as T v
end type

dim a as Box( of long )
dim b as Box( of double )
a = b
