'' Included by BOTH modules, so both instantiate the same generics and both
'' emit them under the same mangled names.  That is the whole test: before
'' Phase 13 this could not be linked at all --
''
''     ld: multiple definition of `Box<int>::GET_()'
''     ld: multiple definition of `_Z5TwiceIiEi'
''
'' A generic instantiation is not module-private by nature: two modules that
'' both say Box( of long ) mean the SAME type, and each emits the members it
'' reached.

type Box( of T )
	as T v
	declare function get_( ) as T
	declare sub set_( byval x as T )
	declare function twice_( ) as T
end type

function Box( of T ).get_( ) as T
	return this.v
end function

sub Box( of T ).set_( byval x as T )
	this.v = x
end sub

function Box( of T ).twice_( ) as T
	return this.v + this.v
end function

'' a generic PROCEDURE, which takes a different emission path from a member
function Twice( of T )( byval x as T ) as T
	return x + x
end function

'' a generic GLOBAL OPERATOR, which takes a third
operator + ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as Box( of T )
	dim r as Box( of T )
	r.v = a.v + b.v
	return r
end operator
