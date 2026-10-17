'' Diagnostics for generic global UNARY operators ('-', '*', '->').
''
'' See readme.txt: this file is compiled for five targets and the output is
'' diffed against the checked-in goldens under r/.
''
'' The unary path instantiates silently, as the binary one does: an operand
'' that fits no generic operator is not an error in itself, and the ordinary
'' diagnostic is reported -- never "Cannot infer type arguments".  Once an
'' operator does fit, an error in its body carries the instantiation chain.

type C( of T )
	as T v
end type

type D( of T )
	as T v
end type

operator - ( of T )( byref x as C( of T ) ) as T
	return -x.v
end operator

operator * ( of T )( byref x as C( of T ) ) byref as T
	return x.v
end operator

operator -> ( of T )( byref x as C( of T ) ) byref as T
	return x.v
end operator

type P
	as long f
end type

dim as D( of long ) dl
dim as C( of P ) cp

#print === unary - on a type no generic - fits: plain type mismatch ===
print -dl

#print === deref * on a type no generic * fits: expected pointer ===
print *dl

#print === -> on a type no generic -> fits: expected pointer ===
print dl->v

#print === -> fits, the member does not exist ===
print cp->nosuch

#print === - fits, its body does not compile for the argument: the chain ===
'' P has no unary '-'
dim as P q = -cp
