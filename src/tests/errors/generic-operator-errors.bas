'' Diagnostics for generic GLOBAL operators.
''
'' See readme.txt: this file is compiled for five targets and the output is
'' diffed against the checked-in goldens under r/.

#print === a self op cannot be global, there is no parent type ===
type A( of T )
	as T v
end type

operator += ( of T )( byref x as A( of T ), byref y as A( of T ) )
	x.v += y.v
end operator

#print === operands binding T two ways report a plain type mismatch ===
'' Inference is silent when it does not fit: the same AST_OP may have ordinary
'' overloads, so a generic operator that cannot bind is not an error in itself.
'' What must NOT appear here is "Cannot infer type arguments".
type C( of T )
	as T v
end type

operator + ( of T )( byref x as C( of T ), byref y as C( of T ) ) as C( of T )
	dim as C( of T ) r
	r.v = x.v + y.v
	return r
end operator

dim as C( of integer ) ci
dim as C( of double ) cd
dim as C( of integer ) cr = ci + cd

#print === unbalanced body, reported at the operator declaration line ===
type B( of T )
	as T v
end type

operator - ( of T )( byref x as B( of T ), byref y as B( of T ) ) as B( of T )
	dim as B( of T ) r
	return r
