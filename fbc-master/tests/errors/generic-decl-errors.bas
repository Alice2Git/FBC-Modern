'' Diagnostics raised at the generic's own declaration, by the structural
'' pre-scan and the type-parameter list parser. These do NOT wait for an
'' instantiation and carry no chain.

#print === duplicate type parameter ===
type Dup( of T, T )
	as T v
end type

#print === no type parameter at all ===
type Empty( of )
	as integer v
end type

#print === type parameter is not an identifier ===
type NotId( of 42 )
	as integer v
end type

#print === done ===
