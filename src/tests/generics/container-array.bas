' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Array( of T ) -- exhaustive.
''
'' Every declared member, every state (empty / one / many), every boundary
'' index, the growth path, every removal form followed by re-insertion, deep
'' copy and assignment independence in both directions, destructor balance, four
'' element types including a nested container, and both FOR EACH binding forms.
''
'' A standard library is the one place a gap is expensive: once this is in the
'' distribution every program depends on it, and a member that was never
'' exercised is a bug shipped to everyone.

#include once "fb/array.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' An element type that counts itself, for the destructor-balance section.
'' Needs the full set: default ctor, copy ctor, LET and dtor -- an Array
'' assigns elements, and every one of those has to balance.
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

'' A plain UDT with '=' and '<', so IndexOf and Sort can be exercised over one.
type Point2
	as long x, y
end type

operator = ( byref a as Point2, byref b as Point2 ) as boolean
	return (a.x = b.x) andalso (a.y = b.y)
end operator

operator < ( byref a as Point2, byref b as Point2 ) as boolean
	if( a.x <> b.x ) then
		return a.x < b.x
	end if
	return a.y < b.y
end operator

	'' ==================================================== the empty state

	scope
		dim a as Array( of long )

		assert_( a.Count( ) = 0 )
		assert_( a.IsEmpty( ) )
		assert_( a.Capacity( ) = 0 )        '' nothing allocated until the first push

		'' every mutator must survive being called on an empty array
		a.Remove( 0 )
		a.RemoveSwap( 0 )
		a.Clear( )
		a.Shrink( )
		assert_( a.Count( ) = 0 )

		'' Pop on empty returns a default-constructed T rather than corrupting
		assert_( a.Pop( ) = 0 )
		assert_( a.Count( ) = 0 )

		'' iterating an empty array runs the body zero times
		dim as long n = 0
		for each v in a
			n += 1
		next
		assert_( n = 0 )

		'' Reserve on empty allocates
		a.Reserve( 3 )
		assert_( a.Capacity( ) >= 3 )
		assert_( a.Count( ) = 0 )
		assert_( a.IsEmpty( ) )
	end scope

	'' ==================================================== one element

	scope
		dim a as Array( of long )
		a.Push( 7 )

		assert_( a.Count( ) = 1 )
		assert_( a.IsEmpty( ) = false )
		assert_( a.Capacity( ) >= 1 )
		assert_( a[ 0 ] = 7 )
		assert_( a.At( 0 ) = 7 )

		dim as long n = 0, sum = 0
		for each v in a
			n += 1 : sum += v
		next
		assert_( n = 1 )
		assert_( sum = 7 )

		assert_( a.Pop( ) = 7 )
		assert_( a.Count( ) = 0 )
		assert_( a.IsEmpty( ) )
	end scope

	'' ==================================================== indexing and bounds

	scope
		dim a as Array( of long )
		for i as long = 0 to 4
			a.Push( i * 10 )
		next

		'' first, middle and last
		assert_( a[ 0 ] = 0 )
		assert_( a[ 2 ] = 20 )
		assert_( a[ a.Count( ) - 1 ] = 40 )

		'' [] is an lvalue and At( ) names the same slot.
		''
		'' At( ) is NOT usable as an assignment target in statement position:
		'' 'a.At( 1 ) = 11' parses as an equality EXPRESSION and warns rather than
		'' assigning.  That is a FreeBASIC rule about byref function results, not
		'' something this container can fix, so At( ) is for reading and for
		'' passing byref, and [] is for writing.
		a[ 1 ] = 99
		assert_( a.At( 1 ) = 99 )
		a[ 1 ] = 11
		assert_( a.At( 1 ) = 11 )

		'' out-of-range indices are refused by the MUTATORS without corrupting
		'' anything.  Reading a[ -1 ] is checked by -exx like a built-in array
		'' and is deliberately not tested here.
		dim as long before = a.Count( )
		a.Remove( -1 )
		a.Remove( before )
		a.Remove( before + 100 )
		a.RemoveSwap( -1 )
		a.RemoveSwap( before )
		a.Insert( -1, 5 )
		a.Insert( before + 1, 5 )
		assert_( a.Count( ) = before )
		assert_( a[ 0 ] = 0 )
		assert_( a[ 4 ] = 40 )
	end scope

	'' ==================================================== growth

	scope
		dim a as Array( of long )

		'' capacity must grow geometrically, not per push: the number of
		'' distinct capacities over 100k pushes is the number of reallocations,
		'' and it has to be O(log n).  This is what "amortised O(1) append"
		'' means, asserted rather than assumed.
		dim as long lastcap = -1, reallocs = 0
		for i as long = 0 to 99999
			a.Push( i )
			if( a.Capacity( ) <> lastcap ) then
				reallocs += 1
				lastcap = a.Capacity( )
			end if
		next

		assert_( a.Count( ) = 100000 )
		assert_( reallocs <= 20 )           '' log2( 100000 / 8 ) + 1 = 15
		assert_( a.Capacity( ) >= 100000 )
		assert_( a.Capacity( ) < 200000 )   '' doubling never overshoots by 2x

		'' every element survived every reallocation
		dim as boolean ok = true
		for i as long = 0 to 99999
			if( a[ i ] <> i ) then ok = false
		next
		assert_( ok )

		'' Reserve does not shrink, and does not disturb the contents
		a.Reserve( 10 )
		assert_( a.Capacity( ) >= 100000 )
		assert_( a[ 0 ] = 0 )

		'' Shrink releases the slack
		a.Shrink( )
		assert_( a.Capacity( ) = 100000 )
		assert_( a[ 99999 ] = 99999 )

		'' Clear keeps the capacity, so a clear-and-refill loop does not realloc
		dim as long cap = a.Capacity( )
		a.Clear( )
		assert_( a.Count( ) = 0 )
		assert_( a.Capacity( ) = cap )

		'' Shrink on an emptied array releases everything
		a.Shrink( )
		assert_( a.Capacity( ) = 0 )
	end scope

	'' ==================================================== insert

	scope
		dim a as Array( of long )
		for i as long = 0 to 2
			a.Push( i )              '' 0 1 2
		next

		a.Insert( 0, 90 )            '' front
		assert_( a.Count( ) = 4 )
		assert_( a[ 0 ] = 90 )
		assert_( a[ 1 ] = 0 )
		assert_( a[ 3 ] = 2 )

		a.Insert( a.Count( ), 91 )   '' at the end, which is legal
		assert_( a.Count( ) = 5 )
		assert_( a[ 4 ] = 91 )

		a.Insert( 2, 92 )            '' middle
		assert_( a.Count( ) = 6 )
		assert_( a[ 2 ] = 92 )
		assert_( a[ 3 ] = 1 )

		'' inserting an element OF THE ARRAY, which is where a naive
		'' implementation reallocates and leaves the byref argument dangling
		dim b as Array( of long )
		b.Reserve( 8 )
		for i as long = 0 to 7
			b.Push( i )              '' exactly full
		next
		b.Insert( 0, b[ 7 ] )        '' forces a realloc while reading itself
		assert_( b.Count( ) = 9 )
		assert_( b[ 0 ] = 7 )
		assert_( b[ 8 ] = 7 )
	end scope

	'' ==================================================== removal, then reuse

	scope
		dim a as Array( of long )
		for i as long = 0 to 4
			a.Push( i )              '' 0 1 2 3 4
		next

		a.Remove( 0 )                '' front; order preserved
		assert_( a.Count( ) = 4 )
		assert_( a[ 0 ] = 1 )
		assert_( a[ 3 ] = 4 )

		a.Remove( a.Count( ) - 1 )   '' back
		assert_( a.Count( ) = 3 )
		assert_( a[ 2 ] = 3 )

		a.Remove( 1 )                '' middle
		assert_( a.Count( ) = 2 )
		assert_( a[ 0 ] = 1 )
		assert_( a[ 1 ] = 3 )

		'' the array is fully usable afterwards
		a.Push( 100 )
		a.Insert( 0, 200 )
		assert_( a.Count( ) = 4 )
		assert_( a[ 0 ] = 200 )
		assert_( a[ 3 ] = 100 )

		'' RemoveSwap: O(1), does NOT preserve order
		dim b as Array( of long )
		for i as long = 0 to 4
			b.Push( i )              '' 0 1 2 3 4
		next
		b.RemoveSwap( 1 )            '' 4 takes 1's place
		assert_( b.Count( ) = 4 )
		assert_( b[ 1 ] = 4 )
		assert_( b[ 3 ] = 3 )

		'' RemoveSwap of the LAST element is the case that swaps with itself
		b.RemoveSwap( b.Count( ) - 1 )
		assert_( b.Count( ) = 3 )
		assert_( b[ 0 ] = 0 )

		'' down to empty, then reuse
		while( b.IsEmpty( ) = false )
			b.RemoveSwap( 0 )
		wend
		assert_( b.Count( ) = 0 )
		b.Push( 42 )
		assert_( b[ 0 ] = 42 )
	end scope

	'' ==================================================== pop drains in order

	scope
		dim a as Array( of long )
		for i as long = 0 to 9
			a.Push( i )
		next

		dim as long got = 0
		for i as long = 9 to 0 step -1
			if( a.Pop( ) = i ) then got += 1
		next
		assert_( got = 10 )
		assert_( a.Count( ) = 0 )
	end scope

	'' ==================================================== copy and assignment

	scope
		dim a as Array( of long )
		for i as long = 0 to 4
			a.Push( i )
		next

		'' copy construction: writing the copy must not touch the original
		dim b as Array( of long ) = a
		assert_( b.Count( ) = 5 )
		b[ 0 ] = 999
		b.Push( 5 )
		assert_( a[ 0 ] = 0 )
		assert_( a.Count( ) = 5 )

		'' ...and writing the ORIGINAL must not touch the copy
		a[ 1 ] = 888
		assert_( b[ 1 ] = 1 )

		'' assignment: same both ways, and the old contents go
		dim c as Array( of long )
		c.Push( 77 )
		c = a
		assert_( c.Count( ) = 5 )
		assert_( c[ 1 ] = 888 )
		c[ 2 ] = 555
		assert_( a[ 2 ] = 2 )
		a[ 3 ] = 444
		assert_( c[ 3 ] = 3 )

		'' assigning an empty array over a full one empties it
		dim d as Array( of long )
		c = d
		assert_( c.Count( ) = 0 )
		assert_( a.Count( ) = 5 )
	end scope

	'' ==================================================== element: string

	scope
		dim a as Array( of string )
		a.Push( "ada" )
		a.Push( "grace" )
		a.Insert( 0, "hopper" )

		assert_( a.Count( ) = 3 )
		assert_( a[ 0 ] = "hopper" )
		assert_( a[ 2 ] = "grace" )

		dim cat as string = ""
		for each s in a
			cat += s + ";"
		next
		assert_( cat = "hopper;ada;grace;" )

		'' byref binding modifies in place
		for each byref s in a
			s = ucase( s )
		next
		assert_( a[ 0 ] = "HOPPER" )

		assert_( a.Pop( ) = "GRACE" )

		'' deep copy of strings
		dim b as Array( of string ) = a
		b[ 0 ] = "changed"
		assert_( a[ 0 ] = "HOPPER" )

		a.Clear( )
		assert_( a.Count( ) = 0 )
	end scope

	'' ==================================================== element: UDT

	scope
		dim a as Array( of Point2 )
		dim as Point2 p
		p.x = 3 : p.y = 4 : a.Push( p )
		p.x = 1 : p.y = 2 : a.Push( p )
		p.x = 3 : p.y = 1 : a.Push( p )

		assert_( a.Count( ) = 3 )
		assert_( a[ 0 ].x = 3 )
		assert_( a[ 0 ].y = 4 )

		'' free generic procedures over a UDT with '=' and '<'
		dim as Point2 want
		want.x = 1 : want.y = 2
		assert_( IndexOf( a, want ) = 1 )
		assert_( Contains( a, want ) )

		want.x = 9 : want.y = 9
		assert_( IndexOf( a, want ) = -1 )
		assert_( Contains( a, want ) = false )

		Sort( a )
		assert_( a[ 0 ].x = 1 )
		assert_( a[ 1 ].x = 3 )
		assert_( a[ 1 ].y = 1 )
		assert_( a[ 2 ].y = 4 )
	end scope

	'' ==================================================== element: nested array
	''
	'' This is what forced IndexOf/Contains/Sort to be free procedures: as
	'' members they would need '=' and '<' on the ELEMENT, and an Array has
	'' neither, so Array( of Array( of long ) ) could not be instantiated at all.

	scope
		dim outer as Array( of Array( of long ) )

		dim inner as Array( of long )
		inner.Push( 1 ) : inner.Push( 2 )
		outer.Push( inner )

		inner.Clear( )
		inner.Push( 3 )
		outer.Push( inner )

		assert_( outer.Count( ) = 2 )
		assert_( outer[ 0 ].Count( ) = 2 )
		assert_( outer[ 0 ][ 1 ] = 2 )
		assert_( outer[ 1 ].Count( ) = 1 )

		'' the inner arrays were COPIED in, not aliased
		inner.Push( 4 )
		assert_( outer[ 1 ].Count( ) = 1 )

		'' and mutating one stored element does not touch the other
		outer[ 0 ].Push( 9 )
		assert_( outer[ 0 ].Count( ) = 3 )
		assert_( outer[ 1 ].Count( ) = 1 )

		'' a deep copy of the outer array deep-copies the inner ones
		dim copy as Array( of Array( of long ) ) = outer
		copy[ 0 ].Push( 10 )
		assert_( outer[ 0 ].Count( ) = 3 )
		assert_( copy[ 0 ].Count( ) = 4 )

		'' iterate a nested container
		dim as long total = 0
		for each sub_ in outer
			total += sub_.Count( )
		next
		assert_( total = 4 )
	end scope

	'' ==================================================== sorting

	scope
		'' already sorted, reversed, all equal, and a size that crosses several
		'' gaps in the sequence
		dim a as Array( of long )
		for i as long = 0 to 99
			a.Push( 99 - i )
		next
		Sort( a )
		dim as boolean ok = true
		for i as long = 0 to 99
			if( a[ i ] <> i ) then ok = false
		next
		assert_( ok )

		Sort( a )                        '' sorting a sorted array
		assert_( a[ 0 ] = 0 )
		assert_( a[ 99 ] = 99 )

		dim b as Array( of long )
		for i as long = 0 to 9
			b.Push( 5 )                  '' all equal
		next
		Sort( b )
		assert_( b[ 0 ] = 5 )
		assert_( b[ 9 ] = 5 )

		dim c as Array( of long )
		Sort( c )                        '' empty
		assert_( c.Count( ) = 0 )
		c.Push( 1 )
		Sort( c )                        '' single
		assert_( c[ 0 ] = 1 )

		'' strings sort too
		dim s as Array( of string )
		s.Push( "pear" ) : s.Push( "apple" ) : s.Push( "fig" )
		Sort( s )
		assert_( s[ 0 ] = "apple" )
		assert_( s[ 1 ] = "fig" )
		assert_( s[ 2 ] = "pear" )
	end scope

	'' ==================================================== IndexOf edges

	scope
		dim a as Array( of long )
		assert_( IndexOf( a, 1L ) = -1 )        '' empty

		a.Push( 5 ) : a.Push( 6 ) : a.Push( 5 )
		assert_( IndexOf( a, 5L ) = 0 )         '' FIRST match, not the last
		assert_( IndexOf( a, 6L ) = 1 )
		assert_( IndexOf( a, 7L ) = -1 )
		assert_( Contains( a, 6L ) )
		assert_( Contains( a, 7L ) = false )
	end scope

	'' ==================================================== FOR EACH forms

	scope
		dim a as Array( of long )
		for i as long = 1 to 5
			a.Push( i )
		next

		'' inferred, copy binding: the array is untouched
		dim as long sum = 0
		for each v in a
			v *= 100
			sum += v
		next
		assert_( sum = 1500 )
		assert_( a[ 0 ] = 1 )

		'' explicit element type
		sum = 0
		for each v as long in a
			sum += v
		next
		assert_( sum = 15 )

		'' byref binding writes through
		for each byref v in a
			v *= 2
		next
		assert_( a[ 0 ] = 2 )
		assert_( a[ 4 ] = 10 )

		'' exit for and continue for
		sum = 0
		for each v in a
			if( v = 4 ) then continue for
			if( v > 8 ) then exit for
			sum += v
		next
		assert_( sum = 2 + 6 + 8 )

		'' nested loops over the same array
		dim as long pairs = 0
		for each x in a
			for each y in a
				pairs += 1
			next
		next
		assert_( pairs = 25 )
	end scope

	'' ==================================================== destructor balance
	''
	'' Every element constructed must be destroyed.  A leak shows up as an
	'' imbalance, which is the memcheck written as an assertion.

	liveCounted = 0
	madeCounted = 0

	scope
		dim a as Array( of Counted )

		for i as long = 0 to 49
			dim as Counted c = Counted( i )
			a.Push( c )
		next
		assert_( a.Count( ) = 50 )
		assert_( a[ 49 ].v = 49 )

		a.Remove( 0 )
		a.RemoveSwap( 0 )
		dim as Counted popped = a.Pop( )
		assert_( a.Count( ) = 47 )

		dim b as Array( of Counted ) = a     '' deep copy of 47 elements
		assert_( b.Count( ) = 47 )

		b.Clear( )
		assert_( b.Count( ) = 0 )

		a.Shrink( )
		assert_( a.Count( ) = 47 )
	end scope

	assert_( madeCounted > 0 )
	assert_( liveCounted = 0 )
