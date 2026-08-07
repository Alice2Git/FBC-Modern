' TEST_MODE : COMPILE_AND_RUN_OK

'' Generic GLOBAL operators.
''
''     operator + ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as Box( of T )
''
'' Two things are new here, and only one of them is the declaration.
''
'' The declaration is the easy half: an operator has no identifier, so the
'' operator token itself leads the captured header and stands in for the name at
'' replay time.  Everything after that is the Phase 5/6 machinery unchanged.
''
'' The hard half is the USE site.  There is nowhere to write explicit type
'' arguments in 'x + y', so the type arguments have to be inferred from the
'' operand types -- and a generic operator's parameters are of the nested shape
'' 'G( of T )', which Phase 6's inference explicitly did not model.  So inference
'' now inverts a nested position: given an operand that is an instantiation of G,
'' each of ITS type arguments binds the corresponding type parameter.
''
'' Nothing is registered until it is instantiated, which is why this cannot be
'' done at declaration time: 'operator +' for Box( of integer ) exists only
'' because somebody added two of them.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T v
end type

type Pair( of T, U )
	as T a
	as U b
end type

'' both operands generic, result generic
operator + ( of T )( byref x as Box( of T ), byref y as Box( of T ) ) as Box( of T )
	dim as Box( of T ) r
	r.v = x.v + y.v
	return r
end operator

'' generic operands, CONCRETE result type
operator = ( of T )( byref x as Box( of T ), byref y as Box( of T ) ) as integer
	return x.v = y.v
end operator

'' a mixed pattern: one nested position and one bare 'T'
operator * ( of T )( byref x as Box( of T ), byval k as T ) as Box( of T )
	dim as Box( of T ) r
	r.v = x.v * k
	return r
end operator

'' two type parameters, both inferred out of one nested position
operator & ( of T, U )( byref p as Pair( of T, U ), byref q as Pair( of T, U ) ) as string
	return str( p.a ) + "/" + q.b
end operator

'' An ordinary, non-generic global operator alongside them.  The generic path
'' must not disturb resolution of one that was never generic.
type Plain
	as integer v
end type

operator - ( byref x as Plain, byref y as Plain ) as Plain
	dim as Plain r
	r.v = x.v - y.v
	return r
end operator

	'' ------------------------------------------------- distinct instantiations

	dim as Box( of integer ) i1, i2
	i1.v = 3 : i2.v = 4

	dim as Box( of integer ) i3 = i1 + i2
	assert_( i3.v = 7 )

	dim as Box( of double ) d1, d2
	d1.v = 1.5 : d2.v = 2.25

	dim as Box( of double ) d3 = d1 + d2
	assert_( d3.v = 3.75 )

	'' a string type argument -- the instantiation that used to collapse onto
	'' another one's external name when the mangler abbreviated it
	dim as Box( of string ) s1, s2
	s1.v = "ab" : s2.v = "cd"

	dim as Box( of string ) s3 = s1 + s2
	assert_( s3.v = "abcd" )

	'' each of the three really is its own body: if two had collapsed onto one
	'' external name the linker would have kept one and these would disagree
	assert_( i3.v = 7 )
	assert_( d3.v = 3.75 )
	assert_( s3.v = "abcd" )

	'' ------------------------------------------------------- concrete result

	assert_( (i1 = i2) = 0 )
	assert_( (i1 = i1) <> 0 )

	'' ------------------------------------------- nested and bare in one header

	dim as Box( of integer ) m = i1 * 10
	assert_( m.v = 30 )

	dim as Box( of double ) md = d1 * 2.0
	assert_( md.v = 3.0 )

	'' ---------------------------------------------------- two type parameters

	dim as Pair( of integer, string ) p, q
	p.a = 7 : p.b = "x"
	q.a = 8 : q.b = "y"

	assert_( (p & q) = "7/y" )

	'' ------------------------------------------------- the non-generic control

	dim as Plain pa, pb
	pa.v = 9 : pb.v = 4
	assert_( (pa - pb).v = 5 )

	'' ---------------------------------------------------------- cache, not new

	'' the second identical use must reach the SAME instantiation; a second
	'' one would be a duplicate definition at link time
	dim as Box( of integer ) i4 = i1 + i2
	assert_( i4.v = 7 )

	'' ----------------------------------------------- chained, and as a subexpr

	dim as Box( of integer ) i5 = i1 + i2 + i1
	assert_( i5.v = 10 )

	assert_( (i1 + i2).v = 7 )
