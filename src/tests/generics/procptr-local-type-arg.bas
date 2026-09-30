' TEST_MODE : COMPILE_AND_RUN_OK

'' A procedure-pointer type written inside a procedure, used as a type
'' argument.
''
'' Its prototype lives in that procedure's scope and is deleted at 'end sub',
'' but the instantiation outlives it: bodies are replayed at the next
'' module-level statement boundary, and later uses of the same arguments hit
'' the cache.  The type parameter was bound to freed memory.  A lambda passed
'' to a generic from inside a generic body -- where the memory is reused at
'' once -- failed with "Expected ')', found 'v'" on 'fn( v )'; from an ordinary
'' procedure it happened to work.  Such arguments are now bound to the global
'' prototype of the same signature.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long hits

function Aplica( of T, F )( byref v as T, byval fn as F ) as boolean
	hits += 1
	return fn( v )
end function

'' a lambda written in a generic body, passed to a generic procedure
function Interior( of T )( byref v as T ) as boolean
	return Aplica( v, function( byref x as T ) as boolean
		return x > 0
	end function )
end function

'' the same on one line
function InteriorOneLine( of T )( byref v as T ) as boolean
	return Aplica( v, function( byref x as T ) as boolean : return x < 0 : end function )
end function

'' a procedure-pointer VARIABLE declared in a generic body: no lambda needed
function ViaPointer( of T )( byref v as T ) as boolean
	dim p as function( byref x as T ) as boolean = _
		function( byref x as T ) as boolean : return x = 7 : end function
	return Aplica( v, p )
end function

'' an ordinary procedure, and a generic TYPE bound to a local procptr type
type Holder( of F )
	as F fn
	declare function Apply( byval x as long ) as long
end type
function Holder( of F ).Apply( byval x as long ) as long
	return this.fn( x )
end function

function InPlainSub( byval x as long ) as long
	dim as Holder( of function( byval n as long ) as long ) h
	h.fn = function( byval n as long ) as long : return n * 3 : end function
	return h.Apply( x )
end function

dim as long n = 5
assert_( Interior( n ) = true )
assert_( InteriorOneLine( n ) = false )
dim as long seven = 7
assert_( ViaPointer( seven ) = true )
assert_( ViaPointer( n ) = false )

dim as double d = -1.5
assert_( Interior( d ) = false )
assert_( InteriorOneLine( d ) = true )

assert_( InPlainSub( 4 ) = 12 )

'' The same signature again, from module level, AFTER the procedures above
'' have ended: this reuses the cached instantiations, whose type parameter
'' must still be a live prototype.
dim as Holder( of function( byval n as long ) as long ) h2
h2.fn = function( byval n as long ) as long : return n + 1 : end function
assert_( h2.Apply( 1 ) = 2 )

dim as function( byref x as long ) as boolean q = _
	function( byref x as long ) as boolean : return x = 5 : end function
assert_( Aplica( n, q ) = true )

assert_( hits = 7 )
