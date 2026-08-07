' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Result( of T, E ) -- exhaustive.
''
'' Every declared member, both states, both free constructors, all four
'' assignment transitions between the states, copy independence both ways,
'' distinct T and E, T = E, a nested container in each position, and destructor
'' balance for BOTH slots -- which is the case a union-based implementation
'' would get wrong.
''
'' The two raising behaviours are NOT here: Value( ) on a failure and Failure( )
'' on a success both abort the process, so they live in result-wrong-side-*.bas
'' as COMPILE_AND_RUN_FAIL tests.

#include once "fb/result.bi"
#include once "fb/array.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' An element type that counts itself, for the destructor-balance section.
dim shared as long liveCounted, madeCounted

type Counted
	as long v
	declare constructor( )
	declare constructor( byval n as long )
	declare constructor( byref rhs as Counted )
	declare operator let( byref rhs as Counted )
	declare destructor( )
end type

constructor Counted( )
	this.v = 0
	liveCounted += 1
	madeCounted += 1
end constructor

constructor Counted( byval n as long )
	this.v = n
	liveCounted += 1
	madeCounted += 1
end constructor

constructor Counted( byref rhs as Counted )
	this.v = rhs.v
	liveCounted += 1
	madeCounted += 1
end constructor

operator Counted.let( byref rhs as Counted )
	this.v = rhs.v
end operator

destructor Counted( )
	liveCounted -= 1
end destructor

'' A plain UDT with no operators at all, used as an E.
type ErrInfo
	as long code
	as long line_
end type

'' The idiomatic spelling: name the pairing once, because both type arguments
'' have to be written out at every Ok( ) / Fail( ) call.
type ParseResult as Result( of long, string )

declare function Parse( byref s as string ) as ParseResult

	'' ==================================================== the default state

	'' A default-constructed Result is a FAILURE.  This is the single most
	'' important property in the file: if it defaulted to Ok, every forgotten
	'' assignment would read as success.
	scope
		dim r as Result( of long, string )

		assert_( r.IsOk( ) = false )

		'' the failure slot is a default-constructed E, not garbage
		assert_( r.Failure( ) = "" )
		assert_( len( r.Failure( ) ) = 0 )

		'' ValueOr never raises, in either state
		dim as long d = -1
		assert_( r.ValueOr( d ) = -1 )
		assert_( r.IsOk( ) = false )         '' and does not change the state
		assert_( r.ValueOr( d ) = -1 )
	end scope

	'' ==================================================== construction by Ok

	scope
		dim r as Result( of long, string ) = Ok( of long, string )( 3L )

		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 3 )

		'' Value is not a consumer -- reading twice is reading twice
		assert_( r.Value( ) = 3 )
		assert_( r.IsOk( ) )

		'' ValueOr on a success ignores the default entirely
		dim as long d = -1
		assert_( r.ValueOr( d ) = 3 )
		assert_( d = -1 )                    '' and does not write through it
	end scope

	'' Zero and the empty string are values, not failures.  This is the property
	'' a global status code cannot express.
	scope
		dim r as Result( of long, string ) = Ok( of long, string )( 0L )
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 0 )

		dim s as Result( of string, string ) = Ok( of string, string )( "" )
		assert_( s.IsOk( ) )
		assert_( s.Value( ) = "" )

		'' and the same shapes as failures, which is the contrast
		dim rf as Result( of long, string )
		assert_( rf.IsOk( ) = false )
		assert_( r.IsOk( ) <> rf.IsOk( ) )
	end scope

	'' ==================================================== construction by Fail

	scope
		dim r as Result( of long, string ) = Fail( of long, string )( "boom" )

		assert_( r.IsOk( ) = false )
		assert_( r.Failure( ) = "boom" )
		assert_( r.Failure( ) = "boom" )     '' not a consumer either

		dim as long d = -1
		assert_( r.ValueOr( d ) = -1 )

		'' an empty failure message is still a failure
		dim blank_ as Result( of long, string ) = Fail( of long, string )( "" )
		assert_( blank_.IsOk( ) = false )
		assert_( blank_.Failure( ) = "" )
	end scope

	'' ==================================================== assignment, all four transitions

	scope
		dim r as Result( of long, string )

		'' failure <- ok
		assert_( r.IsOk( ) = false )
		r = Ok( of long, string )( 1L )
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 1 )

		'' ok <- ok
		r = Ok( of long, string )( 2L )
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 2 )

		'' ok <- failure
		r = Fail( of long, string )( "no" )
		assert_( r.IsOk( ) = false )
		assert_( r.Failure( ) = "no" )

		'' failure <- failure
		r = Fail( of long, string )( "still no" )
		assert_( r.IsOk( ) = false )
		assert_( r.Failure( ) = "still no" )

		'' Result-to-Result assignment, both states
		dim src as Result( of long, string ) = Ok( of long, string )( 5L )
		r = src
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 5 )

		dim bad as Result( of long, string ) = Fail( of long, string )( "x" )
		r = bad
		assert_( r.IsOk( ) = false )
		assert_( r.Failure( ) = "x" )
	end scope

	'' Self-assignment must not corrupt or flip the state.
	scope
		dim r as Result( of long, string ) = Ok( of long, string )( 8L )
		r = r
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 8 )

		dim b as Result( of long, string ) = Fail( of long, string )( "keep me" )
		b = b
		assert_( b.IsOk( ) = false )
		assert_( b.Failure( ) = "keep me" )
	end scope

	'' ==================================================== the slots are independent
	''
	'' Both fields always exist, so a Result carries a stale value across a
	'' transition to failure and vice versa.  That is observable and is pinned
	'' here rather than left as folklore: it is exactly what a union-based
	'' implementation would NOT do.

	scope
		dim r as Result( of long, string ) = Ok( of long, string )( 7L )
		assert_( r.IsOk( ) )
		assert_( r.Value( ) = 7 )

		'' assigning a failure overwrites the whole Result, so the old value goes
		r = Fail( of long, string )( "gone" )
		assert_( r.IsOk( ) = false )
		assert_( r.Failure( ) = "gone" )
		dim as long sentinel = -999
		assert_( r.ValueOr( sentinel ) = -999 )      '' the failure yields the default
	end scope

	'' ==================================================== copy independence

	scope
		dim src as Result( of long, string ) = Ok( of long, string )( 10L )
		dim cpy as Result( of long, string ) = src

		assert_( cpy.IsOk( ) )
		assert_( cpy.Value( ) = 10 )

		'' writing the copy does not touch the source
		cpy = Ok( of long, string )( 20L )
		assert_( src.Value( ) = 10 )
		assert_( cpy.Value( ) = 20 )

		'' and the other direction, which a shared-buffer bug leaves working
		src = Ok( of long, string )( 30L )
		assert_( src.Value( ) = 30 )
		assert_( cpy.Value( ) = 20 )

		'' flipping one's state leaves the other alone
		cpy = Fail( of long, string )( "mine only" )
		assert_( cpy.IsOk( ) = false )
		assert_( src.IsOk( ) )
		assert_( src.Value( ) = 30 )
	end scope

	'' The same for a failure carrying a heap buffer.
	scope
		dim src as Result( of long, string ) = Fail( of long, string )( "original reason" )
		dim cpy as Result( of long, string ) = src

		assert_( cpy.Failure( ) = "original reason" )

		cpy = Fail( of long, string )( "changed reason" )
		assert_( src.Failure( ) = "original reason" )
		assert_( cpy.Failure( ) = "changed reason" )

		src = Ok( of long, string )( 1L )
		assert_( src.IsOk( ) )
		assert_( cpy.Failure( ) = "changed reason" )
	end scope

	'' ==================================================== Value and Failure are BYREF

	scope
		dim r as Result( of long, string ) = Ok( of long, string )( 1L )
		dim byref as long v = r.Value( )

		assert_( v = 1 )
		v = 2
		assert_( r.Value( ) = 2 )
		assert_( r.IsOk( ) )

		'' direct assignment through the byref result, as for Optional
		r.Value( ) = 3
		assert_( r.Value( ) = 3 )
		assert_( v = 3 )                     '' same storage, not a copy

		'' and the failure side
		dim b as Result( of long, string ) = Fail( of long, string )( "a" )
		dim byref as string f = b.Failure( )
		assert_( f = "a" )
		f = "b"
		assert_( b.Failure( ) = "b" )
		assert_( b.IsOk( ) = false )
	end scope

	'' ==================================================== distinct T and E

	scope
		'' E as a UDT with no operators at all
		dim ok_ as Result( of long, ErrInfo ) = Ok( of long, ErrInfo )( 5L )
		assert_( ok_.IsOk( ) )
		assert_( ok_.Value( ) = 5 )

		dim ei as ErrInfo
		ei.code = 404 : ei.line_ = 12

		dim bad as Result( of long, ErrInfo ) = Fail( of long, ErrInfo )( ei )
		assert_( bad.IsOk( ) = false )
		assert_( bad.Failure( ).code = 404 )
		assert_( bad.Failure( ).line_ = 12 )

		'' the stored E is a copy
		ei.code = 500
		assert_( bad.Failure( ).code = 404 )

		'' T as a string, E as a long -- the other way round
		dim s as Result( of string, long ) = Ok( of string, long )( "hi" )
		assert_( s.IsOk( ) )
		assert_( s.Value( ) = "hi" )

		dim sf as Result( of string, long ) = Fail( of string, long )( 42L )
		assert_( sf.IsOk( ) = false )
		assert_( sf.Failure( ) = 42 )
	end scope

	'' ==================================================== T = E
	''
	'' Result( of string, string ) is a normal thing to want: a parsed word, or a
	'' message saying why not.  The slots stay distinct because they are separate
	'' fields rather than a union.

	scope
		dim ok_ as Result( of string, string ) = Ok( of string, string )( "word" )
		assert_( ok_.IsOk( ) )
		assert_( ok_.Value( ) = "word" )

		dim bad as Result( of string, string ) = Fail( of string, string )( "word" )
		assert_( bad.IsOk( ) = false )
		assert_( bad.Failure( ) = "word" )

		'' identical payloads, opposite meanings -- distinguishable
		assert_( ok_.IsOk( ) <> bad.IsOk( ) )

		dim as string d = "(default)"
		assert_( ok_.ValueOr( d ) = "word" )
		assert_( bad.ValueOr( d ) = "(default)" )

		'' writing one slot does not reach the other
		dim both as Result( of string, string ) = Ok( of string, string )( "value side" )
		dim byref as string vs = both.Value( )
		vs = "changed"
		assert_( both.Value( ) = "changed" )
		assert_( both.IsOk( ) )
	end scope

	'' ==================================================== nested containers
	''
	'' The regression test for the no-constraining-members rule, in BOTH
	'' positions: Array has no '=', so a member requiring it would fail to
	'' instantiate here rather than at a call site.

	scope
		dim a as Array( of long )
		a.Push( 1 )
		a.Push( 2 )

		dim r as Result( of Array( of long ), string ) = Ok( of Array( of long ), string )( a )
		assert_( r.IsOk( ) )
		assert_( r.Value( ).Count( ) = 2 )
		assert_( r.Value( )[ 1 ] = 2 )

		'' deep copy: pushing to the source is invisible
		a.Push( 3 )
		assert_( a.Count( ) = 3 )
		assert_( r.Value( ).Count( ) = 2 )

		'' and an Array in the E position
		dim inE as Result( of long, Array( of long ) ) = Fail( of long, Array( of long ) )( a )
		assert_( inE.IsOk( ) = false )
		assert_( inE.Failure( ).Count( ) = 3 )

		'' both positions at once, still instantiable
		dim both as Result( of Array( of long ), Array( of long ) )
		assert_( both.IsOk( ) = false )
		assert_( both.Failure( ).Count( ) = 0 )

		'' and a Result nested inside a Result
		dim nested as Result( of Result( of long, string ), string )
		assert_( nested.IsOk( ) = false )
	end scope

	'' ==================================================== as a return value
	''
	'' The motivating use: a parse that reports why it failed, with the reason in
	'' the return type rather than in a global.

	scope
		dim good as ParseResult = Parse( "42" )
		assert_( good.IsOk( ) )
		assert_( good.Value( ) = 42 )

		dim bad as ParseResult = Parse( "xx" )
		assert_( bad.IsOk( ) = false )
		assert_( bad.Failure( ) = "not a number: xx" )

		'' "0" parses to zero, which is a success -- the case a 0-means-error
		'' convention gets wrong
		dim zero as ParseResult = Parse( "0" )
		assert_( zero.IsOk( ) )
		assert_( zero.Value( ) = 0 )

		'' the empty input is a distinct failure with its own reason
		dim empty_ as ParseResult = Parse( "" )
		assert_( empty_.IsOk( ) = false )
		assert_( empty_.Failure( ) = "empty" )

		'' ValueOr collapses both failures to the same fallback, on purpose
		dim as long d = -1
		assert_( bad.ValueOr( d ) = -1 )
		assert_( empty_.ValueOr( d ) = -1 )
		assert_( zero.ValueOr( d ) = 0 )
	end scope

	'' ==================================================== destructor balance
	''
	'' BOTH slots hold a Counted, so every Result constructs two and must destroy
	'' exactly two.  A union-based implementation that destroyed only the active
	'' slot would leak here and the count would not return to zero.

	liveCounted = 0
	madeCounted = 0

	scope
		dim c as Counted = Counted( 5 )

		dim r as Result( of Counted, Counted ) = Ok( of Counted, Counted )( c )
		assert_( r.IsOk( ) )
		assert_( r.Value( ).v = 5 )

		dim cpy as Result( of Counted, Counted ) = r
		assert_( cpy.Value( ).v = 5 )

		'' flip the copy to a failure -- the value slot is overwritten, not freed
		dim c2 as Counted = Counted( 6 )
		cpy = Fail( of Counted, Counted )( c2 )
		assert_( cpy.IsOk( ) = false )
		assert_( cpy.Failure( ).v = 6 )
		assert_( r.Value( ).v = 5 )

		'' a whole population, both states
		for i as long = 0 to 49
			dim as Counted ci = Counted( i )
			dim as Result( of Counted, Counted ) ri = Ok( of Counted, Counted )( ci )
			assert_( ri.Value( ).v = i )
			ri = Fail( of Counted, Counted )( ci )
			assert_( ri.Failure( ).v = i )
		next

		assert_( r.IsOk( ) )
		assert_( r.Value( ).v = 5 )
	end scope

	'' Asserted AFTER the scope closes, so the Results' own destructors have run.
	'' A double-free shows as a negative count and fails the same assertion as a
	'' leak.
	assert_( madeCounted > 0 )
	assert_( liveCounted = 0 )

	'' The never-set case must balance too: a default-constructed Result still
	'' default-constructs BOTH slots, and must still destroy exactly both.
	liveCounted = 0
	madeCounted = 0

	scope
		dim r as Result( of Counted, Counted )
		assert_( r.IsOk( ) = false )
		assert_( madeCounted = 2 )           '' both fields, default-constructed
		assert_( r.Failure( ).v = 0 )
	end scope

	assert_( liveCounted = 0 )

'' Returns the parsed number, or the reason it could not be parsed.
function Parse( byref s as string ) as ParseResult
	if( len( s ) = 0 ) then
		return Fail( of long, string )( "empty" )
	end if

	for i as long = 0 to len( s ) - 1
		dim as long ch = s[ i ]
		if( (ch < asc( "0" )) orelse (ch > asc( "9" )) ) then
			return Fail( of long, string )( "not a number: " & s )
		end if
	next

	return Ok( of long, string )( clng( valint( s ) ) )
end function
