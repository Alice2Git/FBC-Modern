' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Optional( of T ) -- exhaustive.
''
'' Every declared member, both states (empty / engaged), both free constructors,
'' assignment and reassignment in every direction between the two states, copy
'' independence both ways, four element types including a nested container and a
'' nested Optional, and destructor balance.
''
'' The one behaviour NOT here is Value( ) on an empty Optional: it raises, which
'' aborts the process, so it cannot share a binary with the rest.  It lives in
'' optional-empty-value.bas as a COMPILE_AND_RUN_FAIL test.
''
'' A standard library is the one place a gap is expensive: once this is in the
'' distribution every program depends on it, and a member that was never
'' exercised is a bug shipped to everyone.

#include once "fb/optional.bi"
#include once "fb/array.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' An element type that counts itself, for the destructor-balance section.
'' Needs the full set: default ctor, copy ctor, LET and dtor -- Optional stores
'' a T by value, Some( ) copies into it and Clear( ) assigns over it, and every
'' one of those has to balance.
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

'' A plain UDT with no operators at all.  Optional must instantiate over it --
'' that is the whole point of having no member that constrains T.
type Point2
	as long x, y
end type

'' Defined at the bottom; the module-level body below calls it.
declare function FindFirstEven( byval a as long, byval b as long, byval c as long ) as Optional( of long )

	'' ==================================================== the empty state

	scope
		dim o as Optional( of long )

		'' a default-constructed Optional is empty; there is no third state
		assert_( o.HasValue( ) = false )

		'' Clear( ) on an already-empty Optional is a no-op, not a fault
		o.Clear( )
		assert_( o.HasValue( ) = false )
		o.Clear( )
		assert_( o.HasValue( ) = false )

		'' ValueOr( ) never raises and yields the default
		dim as long d = -1
		assert_( o.ValueOr( d ) = -1 )
		assert_( o.HasValue( ) = false )     '' and does not engage it

		'' a second call gives the same answer -- ValueOr is not a consumer
		assert_( o.ValueOr( d ) = -1 )

		'' a different default is honoured
		dim as long d2 = 99
		assert_( o.ValueOr( d2 ) = 99 )
		assert_( o.ValueOr( d ) = -1 )
	end scope

	'' ==================================================== construction by Some

	scope
		dim as long src = 3
		dim o as Optional( of long ) = Some( src )

		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 3 )

		'' Value( ) is not a consumer either -- reading twice is reading twice
		assert_( o.Value( ) = 3 )
		assert_( o.HasValue( ) )

		'' ValueOr( ) on an engaged Optional ignores the default entirely
		dim as long d = -1
		assert_( o.ValueOr( d ) = 3 )
		assert_( d = -1 )                    '' and does not write through it
	end scope

	'' Some( ) infers T from the ARGUMENT, so an integer literal binds T to
	'' INTEGER, not to LONG.  Some( 3L ) is how a LONG is meant, exactly as
	'' IndexOf( nums, 3L ) already has to be written.
	scope
		dim o as Optional( of long ) = Some( 3L )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 3 )

		dim p as Optional( of integer ) = Some( 3 )
		assert_( p.HasValue( ) )
		assert_( p.Value( ) = 3 )

		dim q as Optional( of double ) = Some( 1.5 )
		assert_( q.HasValue( ) )
		assert_( q.Value( ) > 1.49 andalso q.Value( ) < 1.51 )
	end scope

	'' Zero is a value.  This is the entire motivation for the type: the
	'' sentinel encodings it replaces cannot tell these two apart.
	scope
		dim engagedZero as Optional( of long ) = Some( 0L )
		dim empty_ as Optional( of long )

		assert_( engagedZero.HasValue( ) )
		assert_( empty_.HasValue( ) = false )
		assert_( engagedZero.Value( ) = 0 )

		dim as long d = 0
		assert_( engagedZero.ValueOr( d ) = 0 )
		assert_( empty_.ValueOr( d ) = 0 )
		'' identical results, distinguishable states
		assert_( engagedZero.HasValue( ) <> empty_.HasValue( ) )
	end scope

	'' ==================================================== construction by None

	scope
		dim o as Optional( of long ) = None( of long )( )
		assert_( o.HasValue( ) = false )

		dim as long d = 7
		assert_( o.ValueOr( d ) = 7 )

		'' None( ) and a default-constructed Optional are the same state
		dim p as Optional( of long )
		assert_( o.HasValue( ) = p.HasValue( ) )

		dim s as Optional( of string ) = None( of string )( )
		assert_( s.HasValue( ) = false )
	end scope

	'' ==================================================== Clear

	scope
		dim o as Optional( of long ) = Some( 42L )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 42 )

		o.Clear( )
		assert_( o.HasValue( ) = false )

		dim as long d = -1
		assert_( o.ValueOr( d ) = -1 )

		'' and it can be engaged again afterwards
		o = Some( 43L )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 43 )
	end scope

	'' Clear( ) releases the stored resource NOW rather than at the Optional's
	'' own destruction -- the reason the slot is reset rather than just flagged.
	scope
		dim o as Optional( of string ) = Some( "a rather long string, not a literal in place" )
		assert_( o.HasValue( ) )
		assert_( len( o.Value( ) ) > 20 )

		o.Clear( )
		assert_( o.HasValue( ) = false )

		'' re-engaging after a Clear of a resource-holding T
		o = Some( "short" )
		assert_( o.Value( ) = "short" )
	end scope

	'' ==================================================== assignment, all four transitions

	scope
		dim as long a = 1, b = 2

		'' empty <- engaged
		dim o as Optional( of long )
		assert_( o.HasValue( ) = false )
		o = Some( a )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 1 )

		'' engaged <- engaged
		o = Some( b )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 2 )

		'' engaged <- empty
		o = None( of long )( )
		assert_( o.HasValue( ) = false )

		'' empty <- empty
		o = None( of long )( )
		assert_( o.HasValue( ) = false )

		'' and Optional-to-Optional assignment, both states
		dim p as Optional( of long ) = Some( 5L )
		o = p
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 5 )

		dim q as Optional( of long )
		o = q
		assert_( o.HasValue( ) = false )
	end scope

	'' Self-assignment must not corrupt or disengage.
	scope
		dim o as Optional( of long ) = Some( 8L )
		o = o
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = 8 )

		dim e as Optional( of long )
		e = e
		assert_( e.HasValue( ) = false )
	end scope

	'' ==================================================== copy independence

	scope
		dim src as Optional( of long ) = Some( 10L )
		dim cpy as Optional( of long ) = src        '' copy construction

		assert_( cpy.HasValue( ) )
		assert_( cpy.Value( ) = 10 )

		'' writing the copy does not touch the source
		cpy = Some( 20L )
		assert_( src.Value( ) = 10 )
		assert_( cpy.Value( ) = 20 )

		'' and writing the source does not touch the copy -- the other direction,
		'' which is the one a shared-buffer bug leaves working
		src = Some( 30L )
		assert_( src.Value( ) = 30 )
		assert_( cpy.Value( ) = 20 )

		'' clearing one leaves the other engaged
		cpy.Clear( )
		assert_( cpy.HasValue( ) = false )
		assert_( src.HasValue( ) )
		assert_( src.Value( ) = 30 )
	end scope

	'' The same, for a T that owns a heap buffer.
	scope
		dim src as Optional( of string ) = Some( "original" )
		dim cpy as Optional( of string ) = src

		assert_( cpy.Value( ) = "original" )

		cpy = Some( "changed" )
		assert_( src.Value( ) = "original" )
		assert_( cpy.Value( ) = "changed" )

		src.Clear( )
		assert_( src.HasValue( ) = false )
		assert_( cpy.Value( ) = "changed" )
	end scope

	'' ==================================================== Value( ) is BYREF

	'' Value( ) returns BYREF, so the stored value can be modified in place
	'' through a byref binding, and is also usable directly as an assignment
	'' target.
	''
	'' The direct form is pinned deliberately, because it does NOT behave the
	'' same way as Array.At( ): 'a.At( 0 ) = 11' does not assign, while
	'' 'o.Value( ) = 5' does.  Both compile silently under -w 3, so the only
	'' thing keeping the difference honest is an assertion.
	scope
		dim o as Optional( of long ) = Some( 1L )
		dim byref as long r = o.Value( )

		assert_( r = 1 )
		r = 2
		assert_( o.Value( ) = 2 )
		assert_( o.HasValue( ) )

		'' ValueOr( ) on an engaged Optional aliases the stored value too
		dim as long d = -1
		dim byref as long r2 = o.ValueOr( d )
		r2 = 3
		assert_( o.Value( ) = 3 )
		assert_( d = -1 )

		'' direct assignment through the byref result
		o.Value( ) = 4
		assert_( o.Value( ) = 4 )
		assert_( o.HasValue( ) )
		assert_( r = 4 )                     '' the same storage, not a copy
	end scope

	'' ==================================================== element type: string

	scope
		dim o as Optional( of string )
		assert_( o.HasValue( ) = false )

		dim as string dflt = "(none)"
		assert_( o.ValueOr( dflt ) = "(none)" )

		o = Some( "ada" )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = "ada" )
		assert_( len( o.Value( ) ) = 3 )
		assert_( o.ValueOr( dflt ) = "ada" )

		'' the empty string is a value, and is not absence
		o = Some( "" )
		assert_( o.HasValue( ) )
		assert_( o.Value( ) = "" )
		assert_( o.ValueOr( dflt ) = "" )
	end scope

	'' ==================================================== element type: a UDT with no operators

	scope
		dim p as Point2
		p.x = 3 : p.y = 4

		dim o as Optional( of Point2 ) = Some( p )
		assert_( o.HasValue( ) )
		assert_( o.Value( ).x = 3 )
		assert_( o.Value( ).y = 4 )

		'' mutating the source afterwards does not reach the stored copy
		p.x = 99
		assert_( o.Value( ).x = 3 )

		'' and in place through the byref
		dim byref as Point2 r = o.Value( )
		r.y = 5
		assert_( o.Value( ).y = 5 )

		o.Clear( )
		assert_( o.HasValue( ) = false )

		dim dflt as Point2
		assert_( o.ValueOr( dflt ).x = 0 )
	end scope

	'' ==================================================== element type: a nested container
	''
	'' This is the regression test for the no-constraining-members rule.  Array
	'' has no '=' operator, so an Optional with any member requiring '=' on T
	'' would fail to instantiate here rather than at the call site.

	scope
		dim a as Array( of long )
		a.Push( 1 )
		a.Push( 2 )
		a.Push( 3 )

		dim o as Optional( of Array( of long ) ) = Some( a )
		assert_( o.HasValue( ) )
		assert_( o.Value( ).Count( ) = 3 )
		assert_( o.Value( )[ 0 ] = 1 )
		assert_( o.Value( )[ 2 ] = 3 )

		'' the stored Array is a deep copy -- pushing to the source is invisible
		a.Push( 4 )
		assert_( a.Count( ) = 4 )
		assert_( o.Value( ).Count( ) = 3 )

		'' and pushing through the byref does not reach the source
		dim byref as Array( of long ) r = o.Value( )
		r.Push( 9 )
		assert_( o.Value( ).Count( ) = 4 )
		assert_( o.Value( )[ 3 ] = 9 )
		assert_( a.Count( ) = 4 )
		assert_( a[ 3 ] = 4 )

		o.Clear( )
		assert_( o.HasValue( ) = false )

		dim empty_ as Array( of long )
		assert_( o.ValueOr( empty_ ).Count( ) = 0 )
	end scope

	'' ==================================================== element type: a nested Optional
	''
	'' Optional( of Optional( of T ) ) has three distinguishable states, which is
	'' the property that makes it composable at all.

	scope
		dim inner as Optional( of long ) = Some( 7L )
		dim outer as Optional( of Optional( of long ) ) = Some( inner )

		assert_( outer.HasValue( ) )
		assert_( outer.Value( ).HasValue( ) )
		assert_( outer.Value( ).Value( ) = 7 )

		'' outer engaged, inner empty -- the middle state
		dim emptyInner as Optional( of long )
		outer = Some( emptyInner )
		assert_( outer.HasValue( ) )
		assert_( outer.Value( ).HasValue( ) = false )

		'' outer empty
		outer.Clear( )
		assert_( outer.HasValue( ) = false )
	end scope

	'' ==================================================== an Optional as a return value
	''
	'' The motivating use: a lookup that may legitimately find nothing, without a
	'' sentinel and without an out-parameter.

	scope
		assert_( FindFirstEven( 1, 3, 5 ).HasValue( ) = false )

		dim r as Optional( of long ) = FindFirstEven( 1, 4, 5 )
		assert_( r.HasValue( ) )
		assert_( r.Value( ) = 4 )

		'' the case a -1 sentinel gets wrong
		dim z as Optional( of long ) = FindFirstEven( 1, 0, 5 )
		assert_( z.HasValue( ) )
		assert_( z.Value( ) = 0 )
	end scope

	'' ==================================================== destructor balance

	liveCounted = 0
	madeCounted = 0

	scope
		dim c as Counted = Counted( 5 )

		dim o as Optional( of Counted ) = Some( c )
		assert_( o.HasValue( ) )
		assert_( o.Value( ).v = 5 )

		'' copy construction, then independent reassignment
		dim cpy as Optional( of Counted ) = o
		assert_( cpy.Value( ).v = 5 )

		dim c2 as Counted = Counted( 6 )
		cpy = Some( c2 )
		assert_( cpy.Value( ).v = 6 )
		assert_( o.Value( ).v = 5 )

		'' Clear assigns a blank over the stored element
		cpy.Clear( )
		assert_( cpy.HasValue( ) = false )

		'' a whole population of them, engaged and cleared
		for i as long = 0 to 49
			dim as Counted ci = Counted( i )
			dim as Optional( of Counted ) oi = Some( ci )
			assert_( oi.Value( ).v = i )
			oi.Clear( )
		next

		assert_( o.HasValue( ) )
		assert_( o.Value( ).v = 5 )
	end scope

	'' Asserted AFTER the scope closes, so the Optionals' own destructors have
	'' run.  A double-free shows as a negative count and fails the same assertion
	'' as a leak.
	assert_( madeCounted > 0 )
	assert_( liveCounted = 0 )

	'' The empty case must balance too: an Optional( of Counted ) that is never
	'' engaged still default-constructs its T, and must still destroy exactly it.
	liveCounted = 0
	madeCounted = 0

	scope
		dim o as Optional( of Counted )
		assert_( o.HasValue( ) = false )
		assert_( madeCounted = 1 )           '' the field, default-constructed
		o.Clear( )
		assert_( o.HasValue( ) = false )
	end scope

	assert_( liveCounted = 0 )

'' Returns the first even argument, or nothing.  Zero is even, which is the
'' case the '-1 means not found' idiom cannot express.
function FindFirstEven( byval a as long, byval b as long, byval c as long ) as Optional( of long )
	if( (a and 1) = 0 ) then
		return Some( a )
	end if
	if( (b and 1) = 0 ) then
		return Some( b )
	end if
	if( (c and 1) = 0 ) then
		return Some( c )
	end if
	return None( of long )( )
end function
