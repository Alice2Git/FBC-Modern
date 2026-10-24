' TEST_MODE : COMPILE_AND_RUN_OK

'' A member access straight on the result of a generic call with INFERRED type
'' arguments: 'MakeBox( 2 ).v'.
''
'' The explicit form 'MakeBox( of long )( 2 ).v' went through the ordinary call
'' path, which parses what follows the result; the inferred form returned the
'' bare call, so the '.' was left over -- error 20 (Type mismatch, found '.')
'' in an expression, error 24 / 3 as a statement.  Covered: fields, methods
'' (function and sub), statements, namespace-qualified calls, '->' on a
'' pointer result.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long shown

type Box( of T )
	as T v
	declare sub Show( )
	declare function Twice( ) as T
end type

sub Box( of T ).Show( )
	shown += this.v
end sub

function Box( of T ).Twice( ) as T
	return this.v * 2
end function

function MakeBox( of T )( byval x as T ) as Box( of T )
	dim as Box( of T ) b
	b.v = x
	return b
end function

namespace Ns
	function Make( of T )( byval x as T ) as Box( of T )
		dim as Box( of T ) b
		b.v = x
		return b
	end function

	function Self( of T )( byval p as T ptr ) as T ptr
		return p
	end function
end namespace

'' in expressions
assert_( MakeBox( 2 ).v = 2 )
assert_( MakeBox( of long )( 2 ).v = 2 )
assert_( MakeBox( 7 ).Twice( ) = 14 )
assert_( Ns.Make( 1.5 ).v = 1.5 )
assert_( Ns.Make( 3 ).Twice( ) + MakeBox( 1 ).v = 7 )

'' as statements: a SUB method, a discarded FUNCTION method
MakeBox( 5 ).Show( )
Ns.Make( 6 ).Show( )
MakeBox( 5 ).Twice( )
assert_( shown = 11 )

'' '->' on a pointer result
dim as Box( of long ) q
q.v = 9
assert_( Ns.Self( @q )->v = 9 )
Ns.Self( @q )->Show( )
assert_( shown = 20 )
