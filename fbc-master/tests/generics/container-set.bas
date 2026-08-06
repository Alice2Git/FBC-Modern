' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Set( of T ) -- exhaustive.
''
'' Every declared member including the three set operations, every state, the
'' growth path, tombstones, deep copy and assignment independence in both
'' directions, destructor balance, element types including a user type with its
'' own HashOf, and FOR EACH.

#include once "fb/set.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long liveCounted

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
end constructor

constructor Counted( byval n as long )
	this.v = n
	liveCounted += 1
end constructor

constructor Counted( byref rhs as Counted )
	this.v = rhs.v
	liveCounted += 1
end constructor

operator Counted.let( byref rhs as Counted )
	this.v = rhs.v
end operator

destructor Counted( )
	liveCounted -= 1
end destructor

'' Counted is used as an ELEMENT, so it needs the hash contract too
operator = ( byref x as Counted, byref y as Counted ) as boolean
	return x.v = y.v
end operator

namespace FB
	function HashOf overload ( byref k as Counted ) as ulongint
		return HashOf( k.v )
	end function
end namespace

	'' ==================================================== the empty state

	scope
		dim s as Set( of long )

		assert_( s.Count( ) = 0 )
		assert_( s.IsEmpty( ) )
		assert_( s.Capacity( ) = 0 )

		assert_( s.Contains( 1 ) = false )
		assert_( s.Remove( 1 ) = false )
		assert_( s.Count( ) = 0 )
		assert_( s.Capacity( ) = 0 )        '' a miss must not allocate

		s.Clear( )
		assert_( s.Count( ) = 0 )

		dim as long n = 0
		for each x in s
			n += 1
		next
		assert_( n = 0 )

		assert_( s.Items( ).Count( ) = 0 )

		s.Reserve( 5 )
		assert_( s.Capacity( ) >= 8 )
		assert_( s.Count( ) = 0 )
	end scope

	'' ==================================================== Add reports novelty
	''
	'' 'if s.Add( x ) then' is the "have I seen this before" idiom, so the return
	'' value matters as much as the insertion.

	scope
		dim seen as Set( of long )

		assert_( seen.Add( 42 ) )               '' new
		assert_( seen.Add( 42 ) = false )       '' already there
		assert_( seen.Count( ) = 1 )
		assert_( seen.Contains( 42 ) )
		assert_( seen.Contains( 43 ) = false )

		assert_( seen.Add( 43 ) )
		assert_( seen.Count( ) = 2 )

		'' dedup over a stream with duplicates
		dim s2 as Set( of long )
		dim vals(0 to 7) as long = { 1, 2, 2, 3, 1, 4, 4, 4 }
		dim as long firsts = 0
		for each v in vals
			if( s2.Add( v ) ) then firsts += 1
		next
		assert_( firsts = 4 )
		assert_( s2.Count( ) = 4 )
	end scope

	'' ==================================================== removal, tombstones

	scope
		dim s as Set( of long )
		for i as long = 0 to 99
			s.Add( i )
		next
		assert_( s.Count( ) = 100 )

		assert_( s.Remove( 50 ) )
		assert_( s.Remove( 50 ) = false )
		assert_( s.Count( ) = 99 )

		'' everything else must still be reachable past the tombstone
		dim as boolean ok = true
		for i as long = 0 to 99
			if( i <> 50 ) then
				if( s.Contains( i ) = false ) then ok = false
			end if
		next
		assert_( ok )

		'' re-adding a removed element works
		assert_( s.Add( 50 ) )
		assert_( s.Count( ) = 100 )

		'' churn must not fill the table with tombstones
		dim as long capbefore = s.Capacity( )
		for round as long = 1 to 200
			s.Add( 1000 + round )
			s.Remove( 1000 + round )
		next
		assert_( s.Count( ) = 100 )
		assert_( s.Capacity( ) <= capbefore * 4 )

		'' down to empty, then reuse
		dim items as Array( of long ) = s.Items( )
		for i as long = 0 to items.Count( )-1
			s.Remove( items[ i ] )
		next
		assert_( s.Count( ) = 0 )
		assert_( s.IsEmpty( ) )
		assert_( s.Add( 7 ) )
		assert_( s.Contains( 7 ) )
	end scope

	'' ==================================================== growth

	scope
		dim s as Set( of long )

		for i as long = 0 to 99999
			s.Add( i )
		next
		assert_( s.Count( ) = 100000 )

		dim as boolean ok = true
		for i as long = 0 to 99999
			if( s.Contains( i ) = false ) then ok = false
		next
		assert_( ok )
		assert_( s.Contains( 100000 ) = false )

		'' the load factor is what keeps lookups O(1)
		assert_( s.Capacity( ) * 3 >= s.Count( ) * 4 )
		assert_( s.Capacity( ) <= 262144 )

		'' re-adding 100k existing elements must not grow it
		dim as long cap = s.Capacity( )
		for i as long = 0 to 99999
			s.Add( i )
		next
		assert_( s.Count( ) = 100000 )
		assert_( s.Capacity( ) = cap )

		s.Clear( )
		assert_( s.Count( ) = 0 )
		assert_( s.Contains( 0 ) = false )
	end scope

	'' ==================================================== set operations
	''
	'' a = { 1..5 }, b = { 4..8 }, checked for contents and not just counts.

	scope
		dim a as Set( of long )
		dim b as Set( of long )
		for i as long = 1 to 5
			a.Add( i )
		next
		for i as long = 4 to 8
			b.Add( i )
		next

		'' union
		dim u as Set( of long ) = a
		u.UnionWith( b )
		assert_( u.Count( ) = 8 )
		dim as boolean ok = true
		for i as long = 1 to 8
			if( u.Contains( i ) = false ) then ok = false
		next
		assert_( ok )
		assert_( a.Count( ) = 5 )               '' the operand is untouched

		'' intersection
		dim n as Set( of long ) = a
		n.IntersectWith( b )
		assert_( n.Count( ) = 2 )
		assert_( n.Contains( 4 ) )
		assert_( n.Contains( 5 ) )
		assert_( n.Contains( 3 ) = false )
		assert_( n.Contains( 6 ) = false )
		assert_( b.Count( ) = 5 )

		'' difference
		dim e as Set( of long ) = a
		e.ExceptWith( b )
		assert_( e.Count( ) = 3 )
		assert_( e.Contains( 1 ) )
		assert_( e.Contains( 3 ) )
		assert_( e.Contains( 4 ) = false )

		'' the degenerate cases, which is where these usually break
		dim empty_ as Set( of long )

		dim x as Set( of long ) = a
		x.UnionWith( empty_ )
		assert_( x.Count( ) = 5 )

		x = a
		x.IntersectWith( empty_ )
		assert_( x.Count( ) = 0 )

		x = a
		x.ExceptWith( empty_ )
		assert_( x.Count( ) = 5 )

		x = empty_
		x.UnionWith( a )
		assert_( x.Count( ) = 5 )

		'' with itself
		x = a
		x.UnionWith( x )
		assert_( x.Count( ) = 5 )
		x.IntersectWith( x )
		assert_( x.Count( ) = 5 )

		'' disjoint
		dim d1 as Set( of long )
		dim d2 as Set( of long )
		d1.Add( 1 ) : d1.Add( 2 )
		d2.Add( 3 ) : d2.Add( 4 )
		dim y as Set( of long ) = d1
		y.IntersectWith( d2 )
		assert_( y.Count( ) = 0 )
		y = d1
		y.ExceptWith( d2 )
		assert_( y.Count( ) = 2 )
	end scope

	'' ==================================================== Items snapshot

	scope
		dim s as Set( of string )
		s.Add( "a" ) : s.Add( "b" ) : s.Add( "c" )

		dim items as Array( of string ) = s.Items( )
		assert_( items.Count( ) = 3 )
		assert_( Contains( items, "a" ) )
		assert_( Contains( items, "b" ) )
		assert_( Contains( items, "c" ) )

		'' a snapshot: changing it must not change the set
		items.Clear( )
		assert_( s.Count( ) = 3 )
	end scope

	'' ==================================================== FOR EACH

	scope
		dim s as Set( of long )
		s.Add( 10 ) : s.Add( 20 ) : s.Add( 30 )

		dim as long seen = 0, total = 0
		for each x in s
			seen += 1
			total += x
		next
		assert_( seen = 3 )
		assert_( total = 60 )

		'' explicit element type
		total = 0
		for each x as long in s
			total += x
		next
		assert_( total = 60 )

		'' exit for and continue for
		seen = 0
		for each x in s
			if( x = 20 ) then continue for
			if( x = 99 ) then exit for
			seen += 1
		next
		assert_( seen = 2 )

		'' a removed element must not be yielded
		s.Remove( 20 )
		seen = 0
		for each x in s
			seen += 1
		next
		assert_( seen = 2 )

		'' nested iteration
		dim as long pairs = 0
		for each x in s
			for each y in s
				pairs += 1
			next
		next
		assert_( pairs = 4 )
	end scope

	'' ==================================================== element types

	scope
		'' strings
		dim ss as Set( of string )
		assert_( ss.Add( "ada" ) )
		assert_( ss.Add( "ada" ) = false )
		assert_( ss.Contains( "ada" ) )
		assert_( ss.Contains( "grace" ) = false )
		assert_( ss.Add( "" ) )                 '' the empty string is a value
		assert_( ss.Contains( "" ) )
		assert_( ss.Count( ) = 2 )

		'' a string built at run time must find the literal it equals
		dim as string built = "ad" + "a"
		assert_( ss.Contains( built ) )

		'' doubles, including +0.0 / -0.0
		dim sd as Set( of double )
		sd.Add( 0.0 )
		assert_( sd.Contains( -0.0 ) )
		assert_( sd.Add( -0.0 ) = false )
		assert_( sd.Count( ) = 1 )

		'' a user type through the HashOf extension point
		dim sc as Set( of Counted )
		dim as Counted c1 = Counted( 5 )
		dim as Counted c2 = Counted( 5 )        '' equal, different object
		assert_( sc.Add( c1 ) )
		assert_( sc.Add( c2 ) = false )
		assert_( sc.Contains( c2 ) )
		assert_( sc.Count( ) = 1 )
	end scope

	'' ==================================================== copy and assignment

	scope
		dim a as Set( of long )
		a.Add( 1 ) : a.Add( 2 )

		dim b as Set( of long ) = a
		assert_( b.Count( ) = 2 )

		b.Add( 3 )
		assert_( a.Count( ) = 2 )
		assert_( a.Contains( 3 ) = false )

		a.Add( 4 )
		assert_( b.Contains( 4 ) = false )

		dim c as Set( of long )
		c.Add( 99 )
		c = a
		assert_( c.Count( ) = 3 )
		assert_( c.Contains( 99 ) = false )
		c.Add( 5 )
		assert_( a.Contains( 5 ) = false )

		dim d as Set( of long )
		c = d
		assert_( c.Count( ) = 0 )
		assert_( a.Count( ) = 3 )
	end scope

	'' ==================================================== destructor balance

	liveCounted = 0

	scope
		dim s as Set( of Counted )

		for i as long = 0 to 199
			dim as Counted c = Counted( i )
			s.Add( c )                          '' forces several rehashes
		next
		assert_( s.Count( ) = 200 )

		for i as long = 0 to 199 step 2
			dim as Counted c = Counted( i )
			s.Remove( c )
		next
		assert_( s.Count( ) = 100 )

		dim s2 as Set( of Counted ) = s         '' deep copy
		assert_( s2.Count( ) = 100 )

		s2.Clear( )
		assert_( s2.Count( ) = 0 )
	end scope

	assert_( liveCounted = 0 )
