' TEST_MODE : COMPILE_ONLY_FAIL

'' Two instantiations of one generic are unrelated types, and the compiler knows
'' it statically: asking whether a Root( of integer ) is a Der( of string ) is
'' 'error 298: Types have no hierarchical relation', not a run-time FALSE.
''
'' This is what proves the instantiations are genuinely distinct types rather
'' than one type wearing two names.

type Root( of T ) extends object
	as T v
end type

type Der( of T ) extends Root( of T )
	as T w
end type

dim as Der( of integer ) di
dim as Root( of integer ) ptr r = @di

print ( *r is Der( of string ) )
