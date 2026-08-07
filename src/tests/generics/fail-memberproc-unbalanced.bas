' TEST_MODE : COMPILE_ONLY_FAIL

'' A member body that never closes is caught by the capture's structural
'' pre-scan, at declaration time, not at instantiation.

type Box( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub Box( of T ).setv( byval x as T )
	this.v = x

dim b as Box( of long )
