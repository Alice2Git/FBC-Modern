' TEST_MODE : COMPILE_AND_RUN_OK

'' Capturing a symbol that is itself BYREF.
''
'' A BYREF parameter, a BYREF alias ('dim byref as T r = v') and an imported
'' symbol hold a POINTER to the real storage. The capture used to take such a
'' symbol at face value:
''   BYVAL captured the pointer instead of its target -- "Implicit conversion",
''         and the value never arrived (it read back as 0);
''   BYREF took ADDROF of something that already IS an address, so the closure
''         pointed at the parameter slot -- "Suspicious pointer assignment",
''         garbage on read, writes that never reached the caller's variable.
''
'' cLambdaExpr( ) now makes the same test astBuildVarField( ) does.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ==================================================== BYREF parameters

function ByvalOfByrefParam( byref bias as long ) as long
	var f = function[ byval bias ]( byval x as long ) as long : return x + bias : end function
	return f( 0 )
end function

function ByrefOfByrefParam( byref bias as long ) as long
	var f = function[ byref bias ]( byval x as long ) as long : return x + bias : end function
	return f( 0 )
end function

sub WriteThroughByrefParam( byref dest as long )
	var s = sub[ byref dest ]( byval v as long ) : dest = v : end sub
	s( 7 )
end sub

'' a BYVAL capture is a snapshot taken where the lambda is written
function SnapshotOfByrefParam( byref bias as long ) as long
	var f = function[ byval bias ]( ) as long : return bias : end function
	bias = 99
	return f( )
end function

scope
	dim as long b = 5
	assert_( ByvalOfByrefParam( b ) = 5 )
	assert_( ByrefOfByrefParam( b ) = 5 )
	assert_( SnapshotOfByrefParam( b ) = 5 )
	assert_( b = 99 )

	dim as long o = 0
	WriteThroughByrefParam( o )
	assert_( o = 7 )
end scope

'' ===================================================== BYREF aliases

sub ByrefAlias( )
	dim as long orig = 5
	dim byref as long r = orig

	var f = function[ byval r ]( byval x as long ) as long : return x + r : end function
	assert_( f( 0 ) = 5 )

	var g = sub[ byref r ]( byval v as long ) : r = v : end sub
	g( 9 )
	assert_( orig = 9 )
end sub
ByrefAlias( )

'' ============================== BYVAL parameters and locals still work

function ByvalOfByvalParam( byval bias as long ) as long
	var f = function[ byval bias ]( byval x as long ) as long : return x + bias : end function
	return f( 0 )
end function

sub ByrefOfLocal( )
	dim as long acc = 0
	var s = sub[ byref acc ]( byval v as long ) : acc += v : end sub
	s( 20 )
	s( 22 )
	assert_( acc = 42 )
end sub

assert_( ByvalOfByvalParam( 5 ) = 5 )
ByrefOfLocal( )

'' ======================== a BYREF parameter of a generic, captured

function CountAboveBias( of T )( byref a as T, byref bias as T ) as long
	dim as long k = 0
	var q = sub[ byref k, byval bias ]( byval x as T ) : if x > bias then k += 1 : end if : end sub
	q( a )
	return k
end function

assert_( CountAboveBias( 5, 2 ) = 1 )
assert_( CountAboveBias( 1.0, 2.0 ) = 0 )

'' ============================================ containers, not arrays

'' An ARRAY cannot be captured -- the closure field cannot hold its descriptor,
'' and that is now refused at the capture list itself (error 356) instead of
'' failing later inside the closure's own instantiation. A container is a
'' struct and captures like any other value.
#include once "containers.bi"

sub CaptureContainer( )
	dim as FB.Array( of long ) acc
	var push = sub[ byref acc ]( byval v as long ) : acc.Push( v ) : end sub
	push( 7 )
	push( 8 )
	assert_( acc.Count( ) = 2 )
	assert_( acc.At( 0 ) = 7 )
end sub
CaptureContainer( )
