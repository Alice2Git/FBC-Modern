' TEST_MODE : COMPILE_AND_RUN_OK

'' A capturing lambda after a temporary with a destructor, in the same call.
''
'' A capturing lambda fills its closure's fields with statements of their own,
'' added in the middle of the statement being parsed.  Each astAdd( ) flushed
'' the dtor list, so the temporaries of the arguments BEFORE the lambda were
'' destroyed there -- before the call that creates them -- and never after:
''
''     Use( src.Val_, function[ byval k ]( byref c as Cutie ) ... )
''
'' destroyed Cutie's string on uninitialised stack: heap corruption
'' (0xC0000374) on gas64 and gcc -O 2.  The lambda first, or the temporary in
'' a variable, worked.  Covered: a property result, a function result on both
'' sides of the lambda, two lambdas, in an IF condition and in IIF, with the
'' constructor and destructor counts balanced afterwards.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long ctors, dtors

type Cutie
	as string s
	declare constructor( )
	declare constructor( byref rhs as const Cutie )
	declare destructor( )
end type

constructor Cutie( )
	ctors += 1
end constructor

constructor Cutie( byref rhs as const Cutie )
	ctors += 1
	this.s = rhs.s
end constructor

destructor Cutie( )
	dtors += 1
end destructor

type Sursa
	as string s
	declare property Val_( ) as Cutie
end type

property Sursa.Val_( ) as Cutie
	dim as Cutie c
	c.s = this.s
	return c
end property

function Make( byref s as const string ) as Cutie
	dim as Cutie c
	c.s = s
	return c
end function

function Use( of A, F )( byref a as A, byref f as F ) as long
	return f( a )
end function

function Use3( of A, F, B )( byref a as A, byref f as F, byref b as B ) as long
	return f( a ) * 100 + f( b )
end function

function Use4( of A, F, G )( byref a as A, byref f as F, byref g as G ) as long
	return f( a ) + g( a )
end function

dim as Sursa src
src.s = "din property"
dim as long k = 7

assert_( Use( src.Val_, function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function ) = 19 )
assert_( ctors = dtors )

assert_( Use( Make( "abc" ), function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function ) = 10 )
assert_( ctors = dtors )

assert_( Use3( Make( "ab" ), function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function, Make( "abcd" ) ) = 911 )
assert_( ctors = dtors )

dim as long m = 1
assert_( Use4( Make( "xy" ), _
               function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function, _
               function[ byval m ]( byref c as Cutie ) as long : return m * len( c.s ) : end function ) = 11 )
assert_( ctors = dtors )

dim as long hit = 0
if( Use( src.Val_, function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function ) = 19 ) then
	hit = 1
end if
assert_( hit = 1 )
assert_( ctors = dtors )

dim as long r = iif( k > 0, Use( Make( "q" ), function[ byval k ]( byref c as Cutie ) as long : return k + len( c.s ) : end function ), 0 )
assert_( r = 8 )
assert_( ctors = dtors )
assert_( ctors > 0 )
