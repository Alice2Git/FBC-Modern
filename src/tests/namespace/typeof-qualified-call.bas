' TEST_MODE : COMPILE_AND_RUN_OK

'' TYPEOF / SIZEOF / LEN of a call to a namespace-qualified function.
''
'' 'typeof( N.F( 1 ) )' failed with error 42, Variable not declared, F.  TYPEOF
'' first tries to read a type and consumed 'N.' doing so; the namespace prefix
'' was kept for the expression retry only when the name was a CONST, a
'' variable or a field, so the retry started at a bare 'F'.  A procedure's
'' prefix is kept now too.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

namespace N
	function F( byval x as long ) as long
		return x
	end function
	function D( byval x as double ) as double
		return x
	end function
	function S( ) as string
		return "abc"
	end function
	function O overload( byval x as long ) as long
		return x
	end function
	function O overload( byval x as double ) as double
		return x
	end function
	type T
		as long a, b
	end type
	function MakeT( ) as T
		dim r as T
		return r
	end function
	namespace Inner
		function G( ) as short
			return 1
		end function
	end namespace
end namespace

dim as typeof( N.F( 1 ) ) v = 7
assert_( v = 7 )
assert_( sizeof( v ) = 4 )

assert_( sizeof( N.D( 1 ) ) = 8 )
assert_( sizeof( typeof( N.D( 1 ) ) ) = 8 )

dim as typeof( N.S( ) ) s = N.S( )
assert_( s = "abc" )
assert_( len( N.S( ) ) = 3 )

'' overload resolution still picks by argument
assert_( sizeof( typeof( N.O( 1 ) ) ) = 4 )
assert_( sizeof( typeof( N.O( 1.5 ) ) ) = 8 )

'' a UDT result, and a nested namespace
assert_( sizeof( typeof( N.MakeT( ) ) ) = sizeof( N.T ) )
assert_( sizeof( typeof( N.Inner.G( ) ) ) = 2 )

'' a qualified TYPE and a qualified procedure address are unchanged
dim as typeof( N.T ) t
assert_( sizeof( t ) = 8 )
dim as typeof( @N.F ) p = @N.F
assert_( p( 5 ) = 5 )
