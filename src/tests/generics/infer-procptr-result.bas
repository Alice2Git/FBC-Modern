' TEST_MODE : COMPILE_AND_RUN_OK

'' Inferring a type parameter from a procedure pointer parameter's result.
''
'' The pattern scan took a parameter's type to be whatever follows its LAST
'' 'as' at depth 1, and for 'byval fn as function( ) as R' that is the
'' result: R was bound to the whole procptr type of the argument,
'' 'function( ) as string'.  The instantiation compiled with only two warnings
'' (different pointer types, return type mismatch) and returned garbage.  R now
'' binds to the argument's result type; the procptr's own parameters bind
'' nothing.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T val_
end type

function Run( of R )( byval fn as function( ) as R ) as Box( of R )
	dim as Box( of R ) b
	b.val_ = fn( )
	return b
end function

'' string, integer, UDT results
var bs = Run( function( ) as string : return "sase" : end function )
assert_( bs.val_ = "sase" )
#assert typeof( bs.val_ ) = typeof( string )

var bl = Run( function( ) as long : return 6 : end function )
assert_( bl.val_ = 6 )
#assert typeof( bl.val_ ) = typeof( long )

type Pt
	as long x, y
end type
var bp = Run( function( ) as Pt : return type<Pt>( 1, 2 ) : end function )
assert_( bp.val_.x = 1 andalso bp.val_.y = 2 )

'' a named function's address
private function Seven( ) as double
	return 7.5
end function
var bd = Run( @Seven )
assert_( bd.val_ = 7.5 )
#assert typeof( bd.val_ ) = typeof( double )

'' 'R ptr': R binds to the pointee of the result
dim shared as long g_cell = 42
function Deref( of R )( byval fn as function( ) as R ptr ) as R
	return *fn( )
end function
assert_( Deref( function( ) as long ptr : return @g_cell : end function ) = 42 )

'' the procptr's parameters bind nothing, its result does
function Apply( of R )( byval fn as function( byval k as long ) as R, byval k as long ) as R
	return fn( k )
end function
assert_( Apply( function( byval k as long ) as string : return str( k * 2 ) : end function, 21 ) = "42" )

'' a calling convention, and the same R bound twice
function Or_( of R )( byval fn as function cdecl( ) as R, byval dflt as R ) as R
	dim as R r = fn( )
	if( r = 0 ) then
		return dflt
	end if
	return r
end function
assert_( Or_( function cdecl( ) as integer : return 0 : end function, 9 ) = 9 )

'' a BYREF result
function Ref( of R )( byval fn as function( ) byref as R ) as R
	return fn( )
end function
assert_( Ref( function( ) byref as long : return g_cell : end function ) = 42 )

'' a SUB pointer binds nothing; T comes from the other parameter
function Each( of T )( byval x as T, byval cb as sub( byval v as T ) ) as T
	cb( x )
	return x
end function
dim shared as long g_seen
assert_( Each( 5, sub( byval v as integer ) : g_seen = v : end sub ) = 5 )
assert_( g_seen = 5 )
