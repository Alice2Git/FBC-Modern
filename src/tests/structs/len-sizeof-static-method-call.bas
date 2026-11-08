' TEST_MODE : COMPILE_AND_RUN_OK

'' LEN / SIZEOF / TYPEOF of a call to a method of a UDT, 'len( T.S( ) )'.
''
'' These take a type or an expression.  A name followed by '.' is first tried
'' as a type ('NS.T', a nested type, and 'sizeof( T.field )' all start that
'' way), so the type attempt read 'T' and stopped: 'len( T.S( ) )' failed
'' with Expected ')'.  After the type, a '.' and a method of the UDT now make
'' it a call.  Fields keep going through the type path.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Pt
	as long x, y
end type

type T
	as long f
	as double g
	declare static function S( ) as string
	declare static function N( ) as long
	declare static function P( ) as Pt
	declare static function D( byval k as long ) as double
end type
function T.S( ) as string
	return "abc"
end function
function T.N( ) as long
	return 5
end function
function T.P( ) as Pt
	return type<Pt>( 3, 4 )
end function
function T.D( byval k as long ) as double
	return k * 1.5
end function

namespace NS
	type U
		as short h
		declare static function W( ) as string
	end type
	function U.W( ) as string
		return "wxyz"
	end function
end namespace

'' -------------------------------------------------------------- method calls

assert_( len( T.S( ) ) = 3 )
assert_( sizeof( T.S( ) ) = sizeof( string ) )
assert_( sizeof( T.N( ) ) = 4 )
assert_( sizeof( T.D( 2 ) ) = 8 )
assert_( sizeof( T.P( ) ) = sizeof( Pt ) )

'' a member after the call
assert_( sizeof( T.P( ).x ) = 4 )

'' TYPEOF of the call
dim as typeof( T.S( ) ) s = T.S( )
assert_( s = "abc" )
dim as typeof( T.D( 1 ) ) d = 0.25
assert_( d = 0.25 )

'' a UDT in a namespace
assert_( len( NS.U.W( ) ) = 4 )
assert_( sizeof( NS.U.h ) = 2 )

'' --------------------------------------------- unchanged: fields and types

assert_( sizeof( T.f ) = 4 )
assert_( sizeof( T.g ) = 8 )
assert_( len( T.f ) = 4 )
dim as typeof( T.g ) g = 1.5
assert_( sizeof( g ) = 8 )
assert_( sizeof( T ) = 16 )
assert_( len( Pt ) = 8 )
