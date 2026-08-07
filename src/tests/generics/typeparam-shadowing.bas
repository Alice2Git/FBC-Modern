' TEST_MODE : COMPILE_AND_RUN_OK

'' A variable at the INSTANTIATION SITE must not shadow a TYPE PARAMETER, and
'' the generic's own locals must still shadow its fields.
''
'' The bug: hsymbLookupTypeNS( ) searches locals before the type's namespace --
'' correct inside an ordinary method, where a local should beat a field.  A
'' generic body is replayed at module level in the global namespace, but the
'' instantiation site's block-scope locals are still live, still in the global
'' hash table and still flagged LOCAL, so that pass returned them ahead of the
'' instantiation's own type parameters.
''
'' The effect was severe and silent until triggered: a variable named 't'
'' anywhere in scope broke EVERY 'of T' generic --
''
''     scope
''         dim t as long
''         dim a as Array( of long )        '' error 14: Expected identifier,
''         a.Push( 1 )                      ''           found 'T'
''     end scope
''
'' -- and fbc then hung rather than exiting.  'e' did the same to
'' Result( of T, E ).  Both are ordinary variable names.
''
'' Only declaration replays (a type body, a procedure header) hide the site's
'' locals.  A member BODY replay must not, because its own locals and parameters
'' are exactly what that lookup pass is for -- so both halves are asserted here.

#include once "fb/array.bi"
#include once "fb/optional.bi"
#include once "fb/result.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' A generic whose members deliberately collide with the names below.
type Bx( of T )
	as long num
	as T v
	declare function LocalWins( ) as long
	declare function ParamWins( byval num as long ) as long
	declare function Get( ) byref as T
	declare sub Put( byref x as T )
end type

'' A local named after the FIELD must win over the field.
function Bx( of T ).LocalWins( ) as long
	this.num = 10
	dim num as long = 99
	return num
end function

'' So must a parameter named after the field.
function Bx( of T ).ParamWins( byval num as long ) as long
	this.num = 10
	return num
end function

'' A member whose RETURN TYPE is the type parameter: this is the exact shape
'' that failed, because a field 'as T v' resolves through a different path and
'' kept working while this one did not.
function Bx( of T ).Get( ) byref as T
	return this.v
end function

sub Bx( of T ).Put( byref x as T )
	dim as T t          '' a local named 't' INSIDE a generic body, too
	t = x
	this.v = t
end sub

'' A generic PROCEDURE, which takes the other replay path.
function Ident( of T )( byref x as T ) as T
	return x
end function

'' Defined at the bottom; the module-level body below calls it.
declare function InsideAProc( ) as long

	'' ==================================================== site locals named after type params

	scope
		'' every one of these was fatal before the fix
		dim t as long = 111
		dim e as long = 222

		dim a as Array( of long )
		a.Push( 7 )
		a.Push( 8 )
		assert_( a.Count( ) = 2 )
		assert_( a[ 0 ] = 7 )
		assert_( a[ 1 ] = 8 )

		dim o as Optional( of long ) = Some( 9L )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 9 )

		dim r as Result( of long, string ) = Ok( of long, string )( 5L )
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 5 )

		dim bad as Result( of long, string ) = Fail( of long, string )( "why" )
		assert_( bad.IsOk( ) = false )
		assert_( bad.Failure( ) = "why" )

		'' and the site's own locals are untouched by any of it
		assert_( t = 111 )
		assert_( e = 222 )
	end scope

	'' Nested scopes, and the type parameter named at several depths.
	scope
		dim t as long = 1
		scope
			dim t as long = 2
			scope
				dim e as string = "deep"
				dim a as Array( of string )
				a.Push( "x" )
				assert_( a.Count( ) = 1 )
				assert_( a[ 0 ] = "x" )
				assert_( e = "deep" )
			end scope
			assert_( t = 2 )
		end scope
		assert_( t = 1 )
	end scope

	'' Inside a procedure, not just a module-level scope block.
	scope
		assert_( InsideAProc( ) = 3 )
	end scope

	'' A site local named after the type parameter of a generic PROCEDURE.
	scope
		dim t as long = 333
		assert_( Ident( 42L ) = 42 )
		assert_( Ident( "s" ) = "s" )
		assert_( t = 333 )
	end scope

	'' ==================================================== the generic's own locals still win

	'' The other half: hiding the site's locals must not hide the generic body's
	'' own.  Asserted with and without a colliding site local, because the two
	'' take different paths through the lookup.
	scope
		dim b as Bx( of long )
		assert_( b.LocalWins( ) = 99 )
		assert_( b.ParamWins( 77 ) = 77 )
	end scope

	scope
		dim t as long = 5
		dim num as long = 6

		dim b as Bx( of long )
		assert_( b.LocalWins( ) = 99 )
		assert_( b.ParamWins( 77 ) = 77 )

		'' a member returning T, and a body with its own local named 't'
		b.Put( 41 )
		assert_( b.Get( ) = 41 )

		assert_( t = 5 )
		assert_( num = 6 )
	end scope

	'' The same over a T that is itself a container, so the replay nests.
	scope
		dim t as long = 8
		dim inner as Array( of long )
		inner.Push( 1 )

		dim b as Bx( of Array( of long ) )
		b.Put( inner )
		assert_( b.Get( ).Count( ) = 1 )
		assert_( b.LocalWins( ) = 99 )
		assert_( t = 8 )
	end scope

function InsideAProc( ) as long
	dim t as long = 3
	dim e as long = 4

	dim a as Array( of long )
	a.Push( 1 )
	a.Push( 2 )

	dim o as Optional( of long ) = Some( 2L )
	assert_( o.Value( ) = 2 )
	assert_( a.Count( ) = 2 )
	assert_( e = 4 )

	return t
end function
