' TEST_MODE : COMPILE_AND_RUN_OK

'' Suffixes in generic and lambda bodies.
''
'' A body is captured with LEXCHECK_NOSUFFIX, so a suffix is a token of its
'' own: '&hFFFFFFFFul' is '&hFFFFFFFF' 'ul', 'chr$' is 'chr' '$'.  The replay
'' text put a space between them, and re-lexed it as a number followed by an
'' identifier -- "error 7: Expected ')', found 'ul'" at every instantiation, and
'' in every lambda body.  Tokens written right against each other now stay
'' that way, so the replay lexes as the source did.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

private function U32( byval x as ulong ) as ulong
	return x
end function

'' the literal's type is the suffix's
#macro CHECK_SUFFIXES( )
	assert_( U32( &hFFFFFFFFul ) = 4294967295ull )
	assert_( 123ul = 123 )
	assert_( sizeof( 123ul ) = 4 )
	scope
		dim as typeof( 123ul ) u = -1
		assert_( u > 0 )
	end scope
	assert_( sizeof( 7ll ) = 8 )
	assert_( 7ll - 8 < 0 )
	assert_( sizeof( 9ull ) = 8 )
	assert_( 9ull - 10 > 0 )
	assert_( sizeof( 3l ) = 4 )
	assert_( 5u - 6 > 0 )
	assert_( &hFFul = 255 )
	assert_( &o17ul = 15 )
	assert_( &b101u = 5 )
	assert_( sizeof( 42& ) = 4 )
	assert_( sizeof( 1.5f ) = 4 )
	assert_( sizeof( 2.5! ) = 4 )
	assert_( sizeof( 3.5# ) = 8 )
	assert_( sizeof( 2d ) = 8 )
	assert_( 1e3f = 1000 )
	assert_( chr$( 65 ) = "A" )
	assert_( str$( 5 ) = "5" )
#endmacro

'' a generic member body
type Box( of T )
	as T v
	declare sub Check( )
	declare function Mask( ) as ulong
end type

sub Box( of T ).Check( )
	CHECK_SUFFIXES( )
end sub

function Box( of T ).Mask( ) as ulong
	return v and &hFFFF0000ul
end function

dim as Box( of long ) b
b.Check( )
b.v = &h12345678
assert_( b.Mask( ) = &h12340000ul )

'' a generic procedure, with a suffixed literal in its header too
function Scaled( of T )( byval x as T, byval k as ulong = 10ul ) as T
	CHECK_SUFFIXES( )
	return x * k + 1ul
end function

assert_( Scaled( of long )( 4 ) = 41 )
assert_( Scaled( 4.5, 2ul ) = 10 )

'' a generic type body: an initializer with a suffix
type Limits( of T )
	as T lo = 0ul
	as ulong hi = &hFFFFFFFFul
end type

dim as Limits( of long ) lim
assert_( lim.hi = 4294967295ull )

'' lambdas, capturing and not
var f = function( ) as ulong : return &hFFFFFFFFul : end function
assert_( f( ) = 4294967295ull )

dim as long n = 0
var g = sub[ byref n ]( )
	CHECK_SUFFIXES( )
	n += 5ul
end sub
g( )
assert_( n = 5 )

'' a space is still a space: '#' and '&' apart from the token before them
private function Cat( byval a as string, byval b as string ) as string
	return a & b
end function

function Joined( of T )( byval x as T ) as string
	dim as string a = "a"
	return Cat( a &"b", str( x ) ) & "#"
end function

assert_( Joined( 1 ) = "ab1#" )
