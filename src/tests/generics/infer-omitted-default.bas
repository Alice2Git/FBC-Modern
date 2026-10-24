' TEST_MODE : COMPILE_AND_RUN_OK

'' An inferred generic call may leave out an argument whose parameter has a
'' default, exactly as an ordinary call may: 'Run( lambda )' for
'' 'Run( of F )( byref f as F, byref t as const Tok = tsk_none )'.
''
'' Inference demanded one argument per parameter, so every such call was
'' error 340 (Unable to infer type arguments), although the omitted parameter
'' mentions no type parameter at all.  An omitted argument binds nothing and
'' takes the default; one written out binds as before.  Covered: defaults
'' left out at the end and in the middle, defaults of a concrete type and of
'' type T (with T bound by another argument), a given argument for an 'as T =
'' ...' parameter, defaults with commas and parentheses, procedure pointer
'' and nested 'G( of T )' parameters, statement calls, namespaces.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Tok
	as long id
end type

dim shared as Tok tsk_none

function Run( of F )( byref f as F, byref t as const Tok = tsk_none ) as long
	return f( ) + t.id * 100
end function

function Scale( of T )( byval x as T, byval n as long = 0 ) as T
	return x * (n + 1)
end function

function Add( of T )( byval a as T, byval b as T = 10 ) as T
	return a + b
end function

function Id( of T )( byval x as T = 0 ) as T
	return x
end function

function Three( of T )( byval a as T, byval b as long = 20, byval c as long = 300 ) as T
	return a + b + c
end function

function Cut( of T )( byval x as T, byval s as string = mid( "abcdef", 2, (1 + 2) ) ) as string
	return str( x ) & s
end function

function Seven( ) as long
	return 7
end function

function Call2( of T )( byval x as T, byval cb as function( ) as long = @Seven ) as T
	return x + cb( )
end function

type Box( of T )
	as T v
end type

function Unbox( of T )( byref b as Box( of T ), byval extra as T = 1 ) as T
	return b.v + extra
end function

dim shared as long total

sub Bump( of T )( byval x as T, byval by_ as long = 1 )
	total += x * by_
end sub

namespace Ns
	function Pick( of T )( byval x as T, byval y as long = 5 ) as T
		return x + y
	end function
end namespace

'' the reproducer: a concrete BYREF default, left out and given
dim as Tok t
t.id = 3
assert_( Run( function( ) as long : return 1 : end function ) = 1 )
assert_( Run( function( ) as long : return 2 : end function, t ) = 302 )

'' a numeric default
assert_( Scale( 4 ) = 4 )
assert_( Scale( 4, 2 ) = 12 )
assert_( Scale( 1.5 ) = 1.5 )

'' a default of type T; T comes from the other argument
assert_( Add( 5 ) = 15 )
assert_( Add( 5, 1 ) = 6 )
assert_( Add( 2.5 ) = 12.5 )

'' an argument written out for an 'as T = ...' parameter binds T
assert_( Id( 7 ) = 7 )
assert_( Id( 1.5 ) = 1.5 )

'' left out at the end, in the middle, and both
assert_( Three( 1 ) = 321 )
assert_( Three( 1, 2 ) = 303 )
assert_( Three( 1, 2, 3 ) = 6 )
assert_( Three( 1, , 3 ) = 24 )
assert_( Three( 1, , ) = 321 )

'' commas and parentheses inside the default
assert_( Cut( 9 ) = "9bcd" )
assert_( Cut( 9, "x" ) = "9x" )

'' a procedure pointer default
assert_( Call2( 1 ) = 8 )
assert_( Call2( 1, function( ) as long : return 40 : end function ) = 41 )

'' a nested position binds T, then the default of type T
dim as Box( of long ) b
b.v = 50
assert_( Unbox( b ) = 51 )
assert_( Unbox( b, clng( 9 ) ) = 59 )

'' a statement call
Bump( 3 )
Bump( 3, 10 )
assert_( total = 33 )

'' namespace-qualified
assert_( Ns.Pick( 1 ) = 6 )
assert_( Ns.Pick( 1, 2 ) = 3 )
