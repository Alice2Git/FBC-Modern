' TEST_MODE : COMPILE_ONLY_FAIL

'' Two operands whose nested type arguments disagree bind T to two different
'' types, and RFC-0001 5 forbids picking between them.
''
'' The failure is deliberately NOT reported by inference.  A generic operator
'' that does not fit is not an error in itself -- the same AST_OP may have
'' ordinary overloads, or none -- so inference stays silent and nothing is
'' instantiated, leaving the ordinary "Type mismatch" to be reported at the use
'' site, exactly as it would be for two unrelated UDTs.

type Box( of T )
	as T v
end type

operator + ( of T )( byref x as Box( of T ), byref y as Box( of T ) ) as Box( of T )
	dim as Box( of T ) r
	r.v = x.v + y.v
	return r
end operator

dim as Box( of integer ) a
dim as Box( of double ) b

dim as Box( of integer ) c = a + b
