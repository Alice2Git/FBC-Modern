' TEST_MODE : COMPILE_AND_RUN_OK

'' Lambdas inside generic procedure bodies, and SUB|FUNCTION tokens that are
'' NOT lambdas.
''
'' A generic procedure's body and a lambda's body are both captured as tokens
'' before they are parsed, so both captures have to find their own terminator
'' among nested 'END SUB|FUNCTION's. They used to get it wrong in opposite
'' directions:
''
''   - the generic capture stopped at the FIRST 'end <kind>': a 'function'
''     lambda inside a generic FUNCTION cut the body short, and the rest was
''     parsed at module level -- even if the generic was never instantiated;
''   - the lambda capture counted EVERY SUB|FUNCTION as a nested lambda:
''     'function = x' or 'dim cb as sub( )' inside a lambda left it
''     "Unterminated lambda body".
''
'' Both now share lambdaOpensHere( ).

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type LongFn as function( byval x as long ) as long
type LongSub as sub( byval x as long )

function Dbl( byval x as long ) as long
	return x * 2
end function

'' ====================================== same-kind lambda in a generic body

'' a 'function' lambda in a generic FUNCTION -- the original failure
function Above2( of T )( byref a as T ) as long
	dim p as function( byval x as T ) as boolean = function( byval x as T ) as boolean : return x > 2 : end function
	return iif( p( a ), 1, 0 )
end function

assert_( Above2( 5 ) = 1 )
assert_( Above2( 1 ) = 0 )
assert_( Above2( 7.5 ) = 1 )

'' a 'sub' lambda in a generic SUB
dim shared as long subhits
sub CountAbove2( of T )( byref a as T, byref b as T )
	dim p as sub( byval x as T ) = sub( byval x as T ) : if x > 2 then subhits += 1 : end if : end sub
	p( a )
	p( b )
end sub

subhits = 0
CountAbove2( 1, 5 )
CountAbove2( 3.5, 9.0 )
assert_( subhits = 3 )

'' 'T' inside the lambda means the instantiation's T, for every instantiation
function SizeVia( of T )( ) as long
	dim r as function( ) as long = function( ) as long : return sizeof( T ) : end function
	return r( )
end function

assert_( SizeVia( of long )( ) = 4 )
assert_( SizeVia( of double )( ) = 8 )
assert_( SizeVia( of short )( ) = 2 )

'' multi-line lambda, and a generic that is never instantiated at all
function NeverUsed( of T )( byref a as T ) as long
	dim p as function( byval x as T ) as long = _
		function( byval x as T ) as long
			return x + 1
		end function
	return p( a )
end function

function MultiLine( of T )( byref a as T ) as T
	dim p as function( byval x as T ) as T = _
		function( byval x as T ) as T
			dim as T y = x
			y += x
			return y
		end function
	return p( a )
end function

assert_( MultiLine( 21 ) = 42 )
assert_( MultiLine( 1.25 ) = 2.5 )

'' ============================ SUB|FUNCTION that open NOTHING, in a generic

function NotLambdas( of T )( byref a as T ) as long
	'' procedure types: after AS, and as the first argument of the
	'' type-taking intrinsics
	dim cb as sub( byval as long ) = 0
	dim as any ptr p = procptr( Dbl )
	dim as long r = cast( function( byval as long ) as long, p )( 1 )
	r += sizeof( function( byval as long ) as long ) - sizeof( any ptr )
	dim q as typeof( function( byval as long ) as long ) = cptr( function( byval as long ) as long, p )
	r += q( 1 )

	'' a real lambda among them, of the SAME kind as the generic
	dim f as LongFn = function( byval x as long ) as long : return x + 10 : end function
	r += f( 0 )

	'' result assignment -- must not open anything either
	if( cb = 0 ) then
		function = r + a
		exit function
	end if
	function = -1
end function

assert_( NotLambdas( 100 ) = 114 )  '' 2 + 0 + 2 + 10 + 100

'' ============================== SUB|FUNCTION that open nothing, in a lambda

scope
	dim f as LongFn = function( byval x as long ) as long
		dim cb as sub( byval as long ) = 0
		dim as any ptr p = procptr( Dbl )
		if( cb = 0 ) then
			function = cast( function( byval as long ) as long, p )( x )
			exit function
		end if
		function = -1
	end function
	assert_( f( 21 ) = 42 )
end scope

'' ================================================================ nesting

'' a lambda inside a lambda inside a generic, both of the generic's kind
function Nested( of T )( byref a as T ) as long
	dim outer as function( byval x as long ) as long = _
		function( byval x as long ) as long
			dim inner as LongFn = function( byval y as long ) as long : return y * 3 : end function
			return inner( x ) + 1
		end function
	return outer( a )
end function

assert_( Nested( 5 ) = 16 )

'' a lambda whose RESULT is a procedure type: the second 'function' follows AS
function MakerOf( of T )( ) as long
	dim mk as function( ) as LongFn = function( ) as function( byval x as long ) as long : return @Dbl : end function
	return mk( )( 4 )
end function

assert_( MakerOf( of long )( ) = 8 )

'' a calling convention before the parameter list
function WithCdecl( of T )( byref a as T ) as long
	dim f as function cdecl( byval x as long ) as long = function cdecl( byval x as long ) as long : return x - 1 : end function
	return f( a )
end function

assert_( WithCdecl( 43 ) = 42 )

'' a comment mentioning the terminator changes nothing
function Commented( of T )( byref a as T ) as long
	' end function
	dim f as LongFn = function( byval x as long ) as long : return x + 2 : end function  ' end function
	'' end function
	return f( a )
end function

assert_( Commented( 40 ) = 42 )

'' ======================= methods of generic types, and operators, likewise

type Cell( of T )
	v as T
	declare function Doubled( ) as T
	declare sub Bump( )
end type

function Cell( of T ).Doubled( ) as T
	dim f as function( byval x as T ) as T = function( byval x as T ) as T : return x + x : end function
	return f( v )
end function

sub Cell( of T ).Bump( )
	dim s as sub( byref x as T ) = sub( byref x as T ) : x += 1 : end sub
	s( v )
end sub

scope
	dim c as Cell( of long )
	c.v = 21
	assert_( c.Doubled( ) = 42 )
	c.Bump( )
	assert_( c.v = 22 )

	dim d as Cell( of double )
	d.v = 1.25
	assert_( d.Doubled( ) = 2.5 )
end scope

'' ============================ capturing lambdas see the generic's parameters

'' A closure is a synthesised generic of its own, replayed in its own
'' instantiation's namespace, so the ENCLOSING generic's 'T' used to be
'' invisible to it: 'T' in its header was "Illegal specification", in its body
'' "Variable not declared". It now receives the enclosing type parameters
'' under the same names.

'' 'T' in the header
function CountAbove( of T )( byref a as T, byref b as T ) as long
	dim as long k = 0
	var q = sub[ byref k ]( byval x as T ) : if x > 2 then k += 1 : end if : end sub
	q( a )
	q( b )
	return k
end function

assert_( CountAbove( 1, 5 ) = 1 )
assert_( CountAbove( 3.5, 9.0 ) = 2 )

'' 'T' in the body only
function SizeByClosure( of T )( byref a as T ) as long
	dim as long k = 0
	var q = sub[ byref k ]( ) : k = sizeof( T ) : end sub
	q( )
	return k
end function

assert_( SizeByClosure( cshort( 1 ) ) = 2 )
assert_( SizeByClosure( 1.0 ) = 8 )

'' a BYVAL capture of a T, a T result, and a lambda of the generic's own kind
'' (bias is BYVAL on purpose: a BYVAL capture of a BYREF PARAMETER captures
'' the wrong value -- a separate, pre-existing issue, not specific to generics)
function AddBias( of T )( byref a as T, byval bias as T ) as T
	var f = function[ byval bias ]( byval x as T ) as T : return x + bias : end function
	return f( a )
end function

assert_( AddBias( 40, 2 ) = 42 )
assert_( AddBias( 1.25, 0.5 ) = 1.75 )

'' two type parameters
function Pick( of T, U )( byref a as T, byref b as U ) as long
	dim as long n = 0
	var q = sub[ byref n ]( byval x as T, byval y as U ) : n = sizeof( T ) * 100 + sizeof( U ) : end sub
	q( a, b )
	return n
end function

assert_( Pick( cshort( 1 ), 1.0 ) = 208 )

'' a container of T, captured BYREF
#include once "containers.bi"
function Collect( of T )( byref a as T, byref b as T ) as long
	dim as FB.Array( of T ) acc
	var push = sub[ byref acc ]( byval x as T ) : acc.Push( x ) : end sub
	push( a )
	push( b )
	push( a )
	return acc.Count( )
end function

assert_( Collect( 1, 2 ) = 3 )

'' a method of a generic TYPE
type Counter( of T )
	n as long
	declare sub Feed( byref a as T, byref b as T )
end type

sub Counter( of T ).Feed( byref a as T, byref b as T )
	dim as long k = 0
	var q = sub[ byref k ]( byval x as T ) : if x > 0 then k += sizeof( T ) : end if : end sub
	q( a )
	q( b )
	n = k
end sub

scope
	dim c as Counter( of short )
	c.Feed( 1, 1 )
	assert_( c.n = 4 )
end scope

'' a closure inside a closure: the outer closure's own placeholders must not
'' be passed on to the inner one ("Duplicated type parameter, __C0")
function Nest2( of T )( byref a as T, byref b as T ) as T
	dim as T acc = 0
	var add = sub[ byref acc ]( byval x as T )
		dim as long n = 0
		var inc = sub[ byref n ]( byval y as T ) : n += 1 : end sub
		inc( x )
		acc += x * n
	end sub
	add( a )
	add( b )
	return acc
end function

assert_( Nest2( 20, 22 ) = 42 )
assert_( Nest2( 1.5, 2.25 ) = 3.75 )

'' and the same outside any generic -- the inner 'sub' lambda used to cut the
'' outer closure's body short, since that body is captured as a generic's
scope
	dim as long acc = 0
	var add = sub[ byref acc ]( byval x as long )
		dim as long n = 0
		var inc = sub[ byref n ]( byval y as long ) : n += 1 : end sub
		inc( x )
		acc += x * n
	end sub
	add( 20 )
	add( 22 )
	assert_( acc = 42 )
end scope
