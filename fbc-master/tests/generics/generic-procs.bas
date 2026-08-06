' TEST_MODE : COMPILE_AND_RUN_OK

'' Generic procedures, with explicit type arguments and with inference.
''
'' The header and the body are captured separately and replayed at different
'' times: the header eagerly, as a prototype, the moment a call site needs a
'' callable symbol; the body deferred to a statement boundary, since a call site
'' is mid-expression and no procedure can be opened there.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

sub Swap2( of T )( byref a as T, byref b as T )
	dim tmp as T = a
	a = b
	b = tmp
end sub

function Max( of T )( byval a as T, byval b as T ) as T
	if a > b then return a
	return b
end function

function Deref( of T )( byval p as T ptr ) as T
	return *p
end function

'' the type argument appears ONLY in the return type: callable explicitly, and
'' correctly NOT inferable
function MakeZero( of T )( ) as T
	dim as T z
	return z
end function

'' two type parameters, independently inferred
function Pick( of A, B )( byval x as A, byval y as B ) as A
	return x
end function

'' a generic procedure calling another generic procedure
function Inc( of T )( byval a as T ) as T
	return a + 1
end function

function Inc2( of T )( byval a as T ) as T
	return Inc( of T )( Inc( a ) )
end function

'' a generic type whose method calls a generic procedure -- the instantiation
'' happens inside a replayed body, which is where the scope hoisting matters
type Box( of T )
	as T v
	declare function dbl( ) as T
end type

function Box( of T ).dbl( ) as T
	'' Explicit, not inferred, and deliberately so: 'this.v + this.v' promotes
	'' to INTEGER while 'this.v' stays LONG, so inference would correctly refuse
	'' to choose between them.  See fail-infer-mixed-promotion.bas.
	return Max( of T )( this.v + this.v, this.v )
end function

	'' ---- explicit type arguments ----
	dim as long x = 1, y = 2
	Swap2( of long )( x, y )
	assert_( x = 2 )
	assert_( y = 1 )

	assert_( Max( of long )( 3, 7 ) = 7 )
	assert_( Max( of double )( 2.5, 1.5 ) = 2.5 )
	assert_( Max( of string )( "abc", "abd" ) = "abd" )

	assert_( MakeZero( of long )( ) = 0 )
	assert_( MakeZero( of double )( ) = 0.0 )

	'' ---- inferred ----
	dim as long p = 10, q = 20
	Swap2( p, q )
	assert_( p = 20 )
	assert_( q = 10 )

	dim as string s1 = "aa", s2 = "bb"
	Swap2( s1, s2 )
	assert_( s1 = "bb" )
	assert_( s2 = "aa" )

	assert_( Max( 3, 7 ) = 7 )
	assert_( Max( 2.5, 1.5 ) = 2.5 )

	'' a string LITERAL is a zstring, which cannot be a BYVAL parameter;
	'' inference normalises it to STRING, the only type meant here
	assert_( Max( "abc", "abd" ) = "abd" )

	'' 'T ptr' binds T to the pointee
	dim as long v = 99
	assert_( Deref( @v ) = 99 )

	assert_( Pick( 7, 2.5 ) = 7 )

	assert_( Inc2( of long )( 5 ) = 7 )
	assert_( Inc2( 5 ) = 7 )

	'' explicit and inferred reach the same instantiation
	dim as long a1 = 1, b1 = 2
	dim as long a2 = 1, b2 = 2
	Swap2( of long )( a1, b1 )
	Swap2( a2, b2 )
	assert_( a1 = a2 )
	assert_( b1 = b2 )

	dim bx as Box( of long )
	bx.v = 21
	assert_( bx.dbl( ) = 42 )
