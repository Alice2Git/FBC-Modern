'' Diagnostics at the point a generic is used.

type Box( of T )
	as T v
end type

type Pair( of K, V )
	as K k
	as V v
end type

#print === wrong number of type arguments ===
dim a as Pair( of long )

#print === a generic used with no type argument list ===
dim b as Box

#print === done ===
