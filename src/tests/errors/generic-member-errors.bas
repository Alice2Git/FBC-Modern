'' Diagnostics for out-of-line generic member bodies.
''
'' See readme.txt: this file is compiled for five targets and the output is
'' diffed against the checked-in goldens under r/.

#print === renamed type parameter ===
type A( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub A( of U ).setv( byval x as U )
	this.v = x
end sub

#print === extra type parameter on the body ===
type B( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub B( of T, U ).setv( byval x as T )
	this.v = x
end sub

#print === error inside a member body, with the instantiation chain ===
type C( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub C( of T ).setv( byval x as T )
	this.nosuchfield = x
end sub

dim cc as C( of long )
