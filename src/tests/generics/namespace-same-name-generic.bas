' TEST_MODE : COMPILE_AND_RUN_OK

'' Two generics with the same name, one global and one in a namespace,
'' instantiated with the same type arguments.
''
'' Every instantiation's synthetic namespace is created in the global
'' namespace and was named from the generic's name and the arguments only, so
'' 'Twice( of F )' and 'NS.Twice( of F )' reopened ONE namespace: the second
'' instantiation found the first one's prototype -- 'Expected expression', or
'' an empty line from a PRINT -- and two generic TYPEs named Box collided the
'' same way.  The id now includes the declaring namespace, and the mangled name
'' puts the instantiation in that namespace, as a C++ template there mangles.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

function Inc( byval x as long ) as long
	return x + 1
end function

'' ------------------------------------------------- generic procedures

function Twice( of F )( byval f as F ) as long
	return f( 1 ) * 2
end function

namespace NS
	function Twice( of F )( byval f as F ) as long
		return f( 1 ) * 3
	end function

	namespace Inner
		function Twice( of F )( byval f as F ) as long
			return f( 1 ) * 4
		end function
	end namespace
end namespace

assert_( Twice( @Inc ) = 4 )
assert_( NS.Twice( @Inc ) = 6 )
assert_( NS.Inner.Twice( @Inc ) = 8 )

'' the same through a lambda, multi-line (not inside the macro: a macro
'' argument cannot span lines) and one-line
dim as long viaLambda = NS.Twice( function( byval x as long ) as long
	return x + 1
end function )
assert_( viaLambda = 6 )
assert_( Twice( function( byval x as long ) as long : return x + 1 : end function ) = 4 )
assert_( NS.Twice( function( byval x as long ) as long : return x + 1 : end function ) = 6 )

'' ------------------------------------------------------ generic types

type Box( of T )
	as T v
	declare function Kind( ) as long
end type
function Box( of T ).Kind( ) as long
	return 1
end function

namespace NS
	type Box( of T )
		as T v
		as T w
		declare function Kind( ) as long
	end type
	function Box( of T ).Kind( ) as long
		return 2
	end function
end namespace

scope
	dim as Box( of long ) a
	dim as NS.Box( of long ) b
	assert_( sizeof( a ) = 4 )
	assert_( sizeof( b ) = 8 )
	assert_( a.Kind( ) = 1 )
	assert_( b.Kind( ) = 2 )

	'' and the other way round: the namespace one first
	dim as NS.Box( of double ) c
	dim as Box( of double ) d
	assert_( c.Kind( ) = 2 andalso sizeof( c ) = 16 )
	assert_( d.Kind( ) = 1 andalso sizeof( d ) = 8 )
end scope
