' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic first instantiated in the middle of an expression that already
'' holds string temporaries.
''
'' The instantiation replays the TYPE body on the spot, and END TYPE compiles
'' the implicit constructor, destructor and LET bodies right there.  The list
'' of temporaries awaiting destruction is one global, flushed by the first
'' statement added to ANY procedure, so the caller's pending temporary -- here
'' the string built from "verde" for a BYREF AS CONST STRING parameter -- was
'' destroyed inside the instantiated constructor, where it does not exist:
''
''     error: 'TMP$7$0' undeclared (first use in this function)
''         fb_StrDelete( (FBSTRING*)&TMP$7$0 );   -- in Deriv's constructor
''
'' or, with -gen gas64, the constructor freed a slot of the wrong stack frame
'' and the program crashed.  The caller never destroyed the temporary at all.
'' Instantiating the type in an earlier statement hid it.
''
'' Every type below is first used inside a call, after a literal argument has
'' already produced a temporary, and none is named anywhere before that.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' The reported shape: an implicit constructor that only sets the vptr.
type Baza( of T ) extends object
	declare abstract function Egal( byref a as const T, byref b as const T ) as boolean
end type

type Deriv( of T ) extends Baza( of T )
	declare virtual function Egal( byref a as const T, byref b as const T ) as boolean override
end type

function Deriv( of T ).Egal( byref a as const T, byref b as const T ) as boolean
	return a = b
end function

function Ia( byref s as const string, byref c as Baza( of string ) ) as boolean
	return c.Egal( s, "verde" )
end function

'' A string field: an implicit constructor, copy constructor, LET and
'' destructor, all compiled mid-expression; temporaries on both sides.
type Sir extends object
	declare abstract function Citeste( ) as string
	declare abstract sub Pune( byref s as const string )
end type

type Cutie( of T ) extends Sir
	as T v
	declare virtual function Citeste( ) as string override
	declare virtual sub Pune( byref s as const string ) override
end type

function Cutie( of T ).Citeste( ) as string
	return this.v
end function

sub Cutie( of T ).Pune( byref s as const string )
	this.v = s
end sub

function Lung( byref s as const string, byref c as Sir, byref t as const string ) as integer
	c.Pune( s + t )
	return len( c.Citeste( ) )
end function

'' The same from inside a procedure, with a local in the expression.
type Alt( of T ) extends Baza( of T )
	declare virtual function Egal( byref a as const T, byref b as const T ) as boolean override
end type

function Alt( of T ).Egal( byref a as const T, byref b as const T ) as boolean
	return a <> b
end function

function DinProc( byref x as const string ) as boolean
	dim as string sl = "ver"
	return Ia( sl + x, Alt( of string )( ) ) = false and Ia( "rosu", Alt( of string )( ) )
end function

assert_( Ia( "verde", Deriv( of string )( ) ) )
assert_( Ia( "rosu", Deriv( of string )( ) ) = false )

assert_( Lung( "abcde", Cutie( of string )( ), "xy" ) = 7 )
assert_( Lung( "abcde", Cutie( of string )( ), "xy" ) = 7 )

assert_( DinProc( "de" ) )
