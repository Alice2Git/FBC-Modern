'' Diagnostics for inheritance involving generics.
''
'' See readme.txt: this file is compiled for five targets and the output is
'' diffed against the checked-in goldens under r/.

#print === a generic cannot be extended without a type argument list ===
type A( of T )
	as T v
end type

type BadA extends A
	as integer x
end type

#print === two instantiations are unrelated types, statically ===
type Root( of T ) extends object
	as T v
end type

type Der( of T ) extends Root( of T )
	as T w
end type

dim as Der( of integer ) di
dim as Root( of integer ) ptr r = @di

print ( *r is Der( of string ) )

#print === extending an instantiation that does not compile ===
type Bad( of T ) extends object
	as T v
	declare sub oops( )
end type

sub Bad( of T ).oops( )
	this.nosuchfield = 1
end sub

type UsesBad extends Bad( of integer )
	as integer y
end type

dim as UsesBad ub
