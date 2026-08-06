' TEST_MODE : COMPILE_ONLY_FAIL

'' An out-of-line body must spell the type parameters the way the declaration
'' did.  Binding is by name -- the parameters live as TYPEDEFs under the
'' declaration's names -- so a renamed one would simply fail to resolve, with a
'' far more confusing error than saying so up front.

type Box( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub Box( of U ).setv( byval x as U )
	this.v = x
end sub

dim b as Box( of long )
