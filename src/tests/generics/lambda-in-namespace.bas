' TEST_MODE : COMPILE_AND_RUN_OK

'' A lambda written inside a namespace sees that namespace's names.
''
'' Every lambda is replayed at module level in the global namespace -- its
'' header as a declaration, its body later -- and the replay did not know the
'' namespace the lambda was written in, so 'return x + K' inside 'namespace NS'
'' failed with error 42, Variable not declared, K.  The namespace is now pushed
'' onto the search chain for the replay, as a generic's declaring namespace is.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

namespace NS
	const K = 5
	enum E
		E_A = 3
	end enum
	type Pt
		as long x, y
	end type
	function Helper( byval x as long ) as long
		return x * 10
	end function

	'' a non-capturing lambda: CONST, ENUM and a procedure of the namespace
	function UseNonCapturing( ) as long
		var f = function( byval x as long ) as long
			return x + K + E_A + Helper( 1 )
		end function
		return f( 1 )
	end function

	'' a namespace TYPE in the lambda's own header
	function UseHeaderType( ) as long
		var f = function( byref p as const Pt ) as long
			return p.x + p.y
		end function
		dim as Pt p = ( 2, 3 )
		return f( p )
	end function

	'' a capturing lambda
	function UseCapturing( byval base_ as long ) as long
		var f = function[ byval base_ ]( byval x as long ) as long
			return base_ + x + K
		end function
		return f( 1 )
	end function

	namespace Inner
		const J = 100
		'' a nested namespace sees its own names and the enclosing one's
		function Use( ) as long
			var f = function( ) as long
				return J + K
			end function
			return f( )
		end function
	end namespace
end namespace

assert_( NS.UseNonCapturing( ) = 1 + 5 + 3 + 10 )
assert_( NS.UseHeaderType( ) = 5 )
assert_( NS.UseCapturing( 20 ) = 20 + 1 + 5 )
assert_( NS.Inner.Use( ) = 105 )

'' outside the namespace nothing changed: the names need qualifying
scope
	var g = function( ) as long
		return NS.K + NS.E_A
	end function
	assert_( g( ) = 8 )
end scope
