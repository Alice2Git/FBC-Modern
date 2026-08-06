'' The instantiation chain that generic errors carry.
''
'' An error inside a generic body cannot be reported at the declaration -- it
'' depends on the type argument -- so it surfaces at the instantiation, and the
'' chain says which instantiation and where it was asked for.

#print === one level ===
type Box( of T )
	as T value
	as Wdiget oops
end type

dim b as Box( of long )

#print === two levels: the chain shows both ===
type Inner( of T )
	as Gadgit oops
end type

type Outer( of T )
	as Inner( of T ) v
end type

dim o as Outer( of long )

#print === the same generic at a second argument reports again ===
dim b2 as Box( of string )

#print === done ===
