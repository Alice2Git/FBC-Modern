' TEST_MODE : COMPILE_AND_RUN_OK

'' Constructors, destructors and copy semantics on generic types.
''
'' Most of this already worked once member bodies did (Phase 5): symbStructEnd
'' runs symbUdtDeclareDefaultMembers per instantiation, so implicit ctors/dtors
'' for a generic holding a STRING were already correct, and out-of-line
'' 'constructor Box( of T )( ... )' / 'destructor' / 'operator let' bodies are
'' captured by the same path as any other member body.
''
'' The one thing that did not work was constructing a TEMPORARY --
'' 'Box( of long )( 42 )' in an expression -- because the expression parser
'' dispatches a type name to cCtorCall and had no idea what to do with a
'' generic.  That is what this pins, along with the counts.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long ctors, dtors, copies

type Res( of T )
	as T v
	declare constructor( )
	declare constructor( byval x as T )
	declare constructor( byref rhs as Res( of T ) )
	declare destructor( )
	declare operator let( byref rhs as Res( of T ) )
end type

constructor Res( of T )( )
	ctors += 1
end constructor

constructor Res( of T )( byval x as T )
	this.v = x
	ctors += 1
end constructor

constructor Res( of T )( byref rhs as Res( of T ) )
	this.v = rhs.v
	ctors += 1
	copies += 1
end constructor

destructor Res( of T )( )
	dtors += 1
end destructor

operator Res( of T ).let( byref rhs as Res( of T ) )
	this.v = rhs.v
	copies += 1
end operator

'' a generic holding a STRING, to exercise the IMPLICIT ctor/dtor a
'' string field forces -- no user-declared members at all here
type Plain( of T )
	as T v
end type

sub scope1( )
	dim a as Res( of long ) = Res( of long )( 7 )   '' ctor from a temporary
	dim b as Res( of long ) = a                     '' copy ctor
	dim c as Res( of long )                         '' default ctor
	c = a                                           '' operator let

	assert_( a.v = 7 )
	assert_( b.v = 7 )
	assert_( c.v = 7 )
end sub

sub scope2( )
	'' nested RAII: the outer instantiation holds an inner one, which itself
	'' holds a string
	dim n as Res( of Res( of string ) )
	n.v.v = "deep"
	assert_( n.v.v = "deep" )
end sub

sub scope3( )
	'' no user-declared members; the string field is what forces an implicit
	'' constructor and destructor per instantiation
	dim p as Plain( of string )
	p.v = "hello"
	assert_( p.v = "hello" )

	dim q as Plain( of long )
	q.v = 5
	assert_( q.v = 5 )
end sub

	scope1( )
	assert_( ctors = 3 )    '' ctor(x), copy ctor, default ctor
	assert_( copies = 2 )   '' copy ctor + operator let
	assert_( dtors = 3 )    '' all three destroyed at scope exit

	scope2( )
	'' Res( of Res( of string ) ) default-constructs, and so does its inner
	'' Res( of string ) field
	assert_( ctors = 5 )
	assert_( dtors = 5 )

	scope3( )

	'' the whole point: nothing constructed goes undestroyed
	assert_( ctors = dtors )

	'' a temporary used directly, never bound to a variable
	dim before as long = dtors
	assert_( Res( of long )( 99 ).v = 99 )
	assert_( dtors > before )

	'' distinct instantiations keep distinct members
	dim s as Res( of string ) = Res( of string )( "abc" )
	assert_( s.v = "abc" )
	assert_( ctors <> dtors )   '' 's' is still alive here
