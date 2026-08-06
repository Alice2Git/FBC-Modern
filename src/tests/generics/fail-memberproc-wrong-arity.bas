' TEST_MODE : COMPILE_ONLY_FAIL

'' Same check, the other way: the body may not invent extra type parameters.

type Box( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub Box( of T, U ).setv( byval x as T )
	this.v = x
end sub

dim b as Box( of long )
