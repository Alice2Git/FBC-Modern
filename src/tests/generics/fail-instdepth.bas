' TEST_MODE : COMPILE_ONLY_FAIL
/'
	-maxinstdepth caps how deep one instantiation may drive another.  Nested
	type ARGUMENTS do not count -- they are resolved before the outer body is
	replayed -- so this chains three generics through their bodies instead.
'/
#cmdline "-maxinstdepth 2"

type C3( of T )
	as T v
end type

type B3( of T )
	as C3( of T ) v
end type

type A3( of T )
	as B3( of T ) v
end type

dim a as A3( of long )
