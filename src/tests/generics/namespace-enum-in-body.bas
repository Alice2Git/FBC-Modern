' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic body naming a NON-EXPLICIT ENUM constant of its own namespace,
'' instantiated from outside that namespace.
''
'' namespace-qualified-inst.bas covers a const, a sibling generic and a plain
'' type.  An enum constant is different: it lives in the enum's own hash table,
'' and the namespace only IMPORTS the enum (the implicit 'USING enum' at END
'' ENUM).  The declaring namespace was put back on the search chain for the
'' replay, but without its imports, so the const was found and the enum
'' constant was not -- error 42.  fb/optional.bi and fb/result.bi hit it with
'' FB_RTERROR_ILLEGALFUNCTIONCALL (fberror.bi, an enum in namespace FB), so
'' FB.Optional and FB.Result did not compile without 'using FB'.
''
'' No USING anywhere in this file at module level: that would put the
'' namespaces on the search chain and hide the bug, as it did before.

#include once "fb/optional.bi"
#include once "fb/result.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------------------------ plain enum

namespace N
	enum Codes
		CODE_A = 7
	end enum
	const CODE_B = 8

	function F( of T )( byval x as T ) as long
		return CODE_A + x
	end function

	function G( of T )( byval x as T ) as long
		return CODE_B + x
	end function

	'' a member body, replayed apart from the type body
	type Box( of T )
		as T v
		declare function Code( ) as long
	end type

	function Box( of T ).Code( ) as long
		return CODE_A + this.v
	end function

	'' instantiated from inside the namespace too: the push is refcounted, so
	'' the enum must still be visible here afterwards
	function InsideN( ) as long
		dim as long r = F( 2l )
		return r + CODE_A
	end function

	function AfterInsideN( ) as long
		return CODE_A
	end function
end namespace

assert_( N.F( 1l ) = 8 )
assert_( N.G( 1l ) = 9 )
assert_( N.InsideN( ) = 16 )
assert_( N.AfterInsideN( ) = 7 )

dim as N.Box( of long ) b
b.v = 3
assert_( b.Code( ) = 10 )

'' the enum is still reachable the normal ways
assert_( N.CODE_A = 7 )
assert_( N.Codes.CODE_A = 7 )

'' ------------------------------------------------------------ nested

namespace Outer
	enum OuterCodes
		OC = 100
	end enum

	namespace Inner
		enum InnerCodes
			IC = 20
		end enum

		'' sees its own enum and the enclosing namespace's
		function H( of T )( byval x as T ) as long
			return OC + IC + x
		end function
	end namespace
end namespace

assert_( Outer.Inner.H( 3l ) = 123 )

'' ------------------------------------------------------------ USING inside

namespace M
	const FROM_M = 1000
	enum MCodes
		MC = 50
	end enum
end namespace

namespace U
	'' a USING inside the namespace: code written in U sees M's names, and
	'' so does a generic declared in U, wherever it is instantiated
	using M

	function K( of T )( byval x as T ) as long
		return FROM_M + MC + x
	end function
end namespace

assert_( U.K( 4l ) = 1054 )

'' ------------------------------------------------------------ fb/optional.bi, fb/result.bi

dim as FB.Optional( of long ) o = FB.Some( 7l )
assert_( o.HasValue( ) )
assert_( o.Value( ) = 7 )

dim as FB.Optional( of long ) none_ = FB.None( of long )( )
assert_( none_.HasValue( ) = false )
assert_( none_.ValueOr( 5 ) = 5 )

dim as FB.Result( of long, string ) r = FB.Ok( of long, string )( 3l )
assert_( r.IsOk( ) )
assert_( r.Value( ) = 3 )

dim as FB.Result( of long, string ) rf = FB.Fail( of long, string )( "no" )
assert_( rf.IsOk( ) = false )
assert_( rf.Failure( ) = "no" )

'' ------------------------------------------------------------ from another namespace

'' the instantiation request comes from a library's own namespace: a field
'' type, and a local inside a procedure body there
namespace MyLib
	type LoopResult
		as boolean completed
		as FB.Optional( of longint ) lowest
	end type

	function Halve( byval n as long ) as FB.Result( of double, string )
		if( n = 0 ) then
			return FB.Fail( of double, string )( "zero" )
		end if
		dim as FB.Optional( of double ) h = FB.Some( n / 2.0 )
		return FB.Ok( of double, string )( h.Value( ) )
	end function
end namespace

dim as MyLib.LoopResult lr
assert_( lr.lowest.HasValue( ) = false )
lr.lowest = FB.Some( 12ll )
assert_( lr.lowest.Value( ) = 12 )

assert_( MyLib.Halve( 5 ).Value( ) = 2.5 )
assert_( MyLib.Halve( 0 ).Failure( ) = "zero" )
