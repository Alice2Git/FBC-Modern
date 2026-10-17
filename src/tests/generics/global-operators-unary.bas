' TEST_MODE : COMPILE_AND_RUN_OK

'' Generic global UNARY operators: '-', '+', 'not', '*' (deref) and '->'.
''
'' They were accepted when declared and never found at use:
''
''     error 20: Type mismatch in 'print -g'
''     error 28: Expected pointer, before ')' in 'print ( *g )'
''     error 28: Expected pointer, before '->' in 'print p->v'
''
'' A generic operator is in globOpOvlTb only once it is instantiated, and only
'' the BOP path (hDoGlobOpOverload) tried to instantiate one.  astNewUOP() and
'' the '*' / '->' overload lookups on a UDT now do the same, with one operand.
''
'' Two more things the unary path has to get right, both covered below:
''
''   - the declaration does not know '-' from negation, or '*' from a deref:
''     only the parameter count decides, so a one-parameter generic '-' has to
''     be found for NEG and a two-parameter one for SUB, side by side;
''   - '->' and '*' on a UDT are looked up away from astNewUOP, by
''     cMemberDeref() and astBuildMultiDeref().
''
'' Reported by xSmartPtr as b01.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T v
end type

operator - ( of T )( byref b as Box( of T ) ) as T
	return -b.v
end operator

operator + ( of T )( byref b as Box( of T ) ) as T
	return b.v + 100
end operator

operator not ( of T )( byref b as Box( of T ) ) as T
	return not b.v
end operator

'' the binary '-' and '*' alongside the unary ones, for the same generic
operator - ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as T
	return a.v - b.v
end operator

operator * ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as T
	return a.v * b.v
end operator

operator * ( of T )( byref b as Box( of T ) ) byref as T
	return b.v
end operator

type Point
	as long x, y
	declare function Sum( ) as long
end type

function Point.Sum( ) as long
	return x + y
end function

'' a smart-pointer shape: '->' and '*' reach the pointee
type Ref( of T )
	as T ptr p
end type

operator -> ( of T )( byref r as Ref( of T ) ) byref as T
	return *r.p
end operator

operator * ( of T )( byref r as Ref( of T ) ) byref as T
	return *r.p
end operator

	'' ------------------------------------------------------------ - + not

	dim as Box( of long ) b, c
	b.v = 4
	c.v = 3

	assert_( -b = -4 )
	assert_( +b = 104 )
	assert_( (not b) = -5 )

	'' unary and binary, same token, same generic
	assert_( b - c = 1 )
	assert_( b * c = 12 )
	assert_( -b - -c = -1 )

	'' another instantiation of the same operators
	dim as Box( of double ) d
	d.v = 1.5
	assert_( -d = -1.5 )

	'' ---------------------------------------------------------------- deref

	assert_( *b = 4 )
	*b = 9
	assert_( b.v = 9 )

	'' ------------------------------------------------------- '->' and '*'

	dim as Point pt = ( 2, 5 )
	dim as Ref( of Point ) r
	r.p = @pt

	assert_( r->x = 2 )
	assert_( r->Sum( ) = 7 )
	r->y = 10
	assert_( pt.y = 10 )
	assert_( (*r).Sum( ) = 12 )

	dim as long n = 42
	dim as Ref( of long ) rn
	rn.p = @n
	assert_( *rn = 42 )
