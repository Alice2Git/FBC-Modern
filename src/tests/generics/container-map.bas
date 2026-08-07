' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Map( of TK, TV ) -- exhaustive.
''
'' Every declared member, every state, the four readers/writers that every
'' dictionary API gets wrong, the growth path, tombstones, deep copy and
'' assignment independence in both directions, destructor balance, key and value
'' types including a user type with its own HashOf, and FOR EACH.

#include once "fb/map.bi"
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

'' A user-defined key: the hash contract is an overloaded HashOf plus '=', and
'' the overload is added by RE-OPENING the namespace.  This is the extension
'' point, and it has to work or no user type can ever be a key.
type PairKey
	as long a, b
end type

operator = ( byref x as PairKey, byref y as PairKey ) as boolean
	return (x.a = y.a) andalso (x.b = y.b)
end operator

namespace FB
	function HashOf overload ( byref k as PairKey ) as ulongint
		'' equal keys must hash equal -- derived only from the compared fields
		return HashOf( k.a ) xor (HashOf( k.b ) shl 1)
	end function
end namespace

	'' ==================================================== the empty state

	scope
		dim m as Map( of string, long )

		assert_( m.Count( ) = 0 )
		assert_( m.IsEmpty( ) )
		assert_( m.Capacity( ) = 0 )

		'' every reader must survive an empty map, and none may allocate
		assert_( m.Contains( "nope" ) = false )
		dim as long got = 123
		assert_( m.TryGet( "nope", got ) = false )
		assert_( got = 123 )                    '' left alone on a miss
		assert_( m.Remove( "nope" ) = false )
		assert_( m.Count( ) = 0 )
		assert_( m.Capacity( ) = 0 )

		m.Clear( )
		assert_( m.Count( ) = 0 )

		dim as long n = 0
		for each kv in m
			n += 1
		next
		assert_( n = 0 )

		assert_( m.Keys( ).Count( ) = 0 )
		assert_( m.Values( ).Count( ) = 0 )

		m.Reserve( 5 )
		assert_( m.Capacity( ) >= 8 )
		assert_( m.Count( ) = 0 )
	end scope

	'' ==================================================== Add / Put / [] / TryGet
	''
	'' The four of these are where every dictionary API in every language causes
	'' bugs, so each one is pinned against the other three.

	scope
		dim m as Map( of string, long )

		'' Add inserts and reports NEW
		assert_( m.Add( "ada", 36 ) )
		assert_( m.Count( ) = 1 )

		'' Add on an existing key reports FALSE and does NOT overwrite
		assert_( m.Add( "ada", 99 ) = false )
		assert_( m.Count( ) = 1 )
		dim as long got
		assert_( m.TryGet( "ada", got ) )
		assert_( got = 36 )                     '' still the original

		'' Put overwrites, and reports whether the key was new
		assert_( m.Put( "ada", 37 ) = false )   '' existed
		assert_( m.TryGet( "ada", got ) )
		assert_( got = 37 )
		assert_( m.Put( "grace", 85 ) )         '' new
		assert_( m.Count( ) = 2 )

		'' Contains and TryGet do NOT insert
		dim as long before = m.Count( )
		assert_( m.Contains( "edsger" ) = false )
		assert_( m.TryGet( "edsger", got ) = false )
		assert_( m.Count( ) = before )

		'' the indexer DOES insert on a miss -- documented, and the reason
		'' TryGet exists
		assert_( m[ "edsger" ] = 0 )            '' default-constructed
		assert_( m.Count( ) = before + 1 )
		assert_( m.Contains( "edsger" ) )

		'' and it is an lvalue
		m[ "edsger" ] = 45
		assert_( m[ "edsger" ] = 45 )

		'' which is what makes the counting idiom work
		dim counts as Map( of string, long )
		dim words(0 to 5) as string = { "a", "b", "a", "c", "b", "a" }
		for each w in words
			counts[ w ] += 1
		next
		assert_( counts.Count( ) = 3 )
		assert_( counts[ "a" ] = 3 )
		assert_( counts[ "b" ] = 2 )
		assert_( counts[ "c" ] = 1 )
	end scope

	'' ==================================================== removal and tombstones

	scope
		dim m as Map( of long, long )
		for i as long = 0 to 99
			m.Put( i, i * 2 )
		next
		assert_( m.Count( ) = 100 )

		'' remove reports whether anything went
		assert_( m.Remove( 50 ) )
		assert_( m.Remove( 50 ) = false )
		assert_( m.Count( ) = 99 )
		assert_( m.Contains( 50 ) = false )

		'' everything else is still reachable -- this is the assertion that
		'' catches a removal which blanks a slot instead of tombstoning it and
		'' so cuts the probe chain
		dim as boolean ok = true
		for i as long = 0 to 99
			if( i <> 50 ) then
				if( m.Contains( i ) = false ) then ok = false
			end if
		next
		assert_( ok )

		'' re-inserting a removed key works, and should reuse the tombstone
		assert_( m.Put( 50, 999 ) )
		assert_( m.Count( ) = 100 )
		assert_( m[ 50 ] = 999 )

		'' remove every other key, then check both halves
		for i as long = 0 to 99 step 2
			m.Remove( i )
		next
		assert_( m.Count( ) = 50 )
		ok = true
		for i as long = 1 to 99 step 2
			if( m.Contains( i ) = false ) then ok = false
		next
		for i as long = 0 to 99 step 2
			if( m.Contains( i ) ) then ok = false
		next
		assert_( ok )

		'' a churn loop must not fill the table with tombstones: capacity has to
		'' stay bounded, which only happens if rehashing drops them
		dim as long capbefore = m.Capacity( )
		for round as long = 1 to 200
			m.Put( 1000 + round, round )
			m.Remove( 1000 + round )
		next
		assert_( m.Count( ) = 50 )
		assert_( m.Capacity( ) <= capbefore * 4 )

		'' down to empty, then reuse
		dim ks as Array( of long ) = m.Keys( )
		for i as long = 0 to ks.Count( )-1
			m.Remove( ks[ i ] )
		next
		assert_( m.Count( ) = 0 )
		assert_( m.IsEmpty( ) )
		m.Put( 7, 7 )
		assert_( m[ 7 ] = 7 )
	end scope

	'' ==================================================== growth

	scope
		dim m as Map( of long, long )

		for i as long = 0 to 99999
			m.Put( i, i * 3 )
		next

		assert_( m.Count( ) = 100000 )

		'' every key survived every rehash
		dim as boolean ok = true
		for i as long = 0 to 99999
			dim as long got
			if( m.TryGet( i, got ) = false ) then ok = false
			if( got <> i * 3 ) then ok = false
		next
		assert_( ok )

		'' the load factor is respected, which is what keeps lookups O(1):
		'' capacity must exceed count/0.75 and must not be wildly bigger
		assert_( m.Capacity( ) * 3 >= m.Count( ) * 4 )
		assert_( m.Capacity( ) <= 262144 )

		'' overwriting 100k keys must not grow it at all
		dim as long cap = m.Capacity( )
		for i as long = 0 to 99999
			m.Put( i, i )
		next
		assert_( m.Count( ) = 100000 )
		assert_( m.Capacity( ) = cap )

		m.Clear( )
		assert_( m.Count( ) = 0 )
		assert_( m.Contains( 0 ) = false )
	end scope

	'' ==================================================== Keys and Values

	scope
		dim m as Map( of string, long )
		m.Put( "a", 1 )
		m.Put( "b", 2 )
		m.Put( "c", 3 )

		dim ks as Array( of string ) = m.Keys( )
		dim vs as Array( of long ) = m.Values( )
		assert_( ks.Count( ) = 3 )
		assert_( vs.Count( ) = 3 )

		'' order is unspecified, so check membership and the total
		assert_( Contains( ks, "a" ) )
		assert_( Contains( ks, "b" ) )
		assert_( Contains( ks, "c" ) )
		dim as long total = 0
		for each v in vs
			total += v
		next
		assert_( total = 6 )

		'' they are SNAPSHOTS: changing them must not change the map
		ks.Clear( )
		assert_( m.Count( ) = 3 )
	end scope

	'' ==================================================== FOR EACH

	scope
		dim m as Map( of string, long )
		m.Put( "a", 10 )
		m.Put( "b", 20 )
		m.Put( "c", 30 )

		dim as long seen = 0, total = 0
		for each kv in m
			seen += 1
			total += kv.value
			assert_( len( kv.key ) = 1 )
		next
		assert_( seen = 3 )
		assert_( total = 60 )

		'' exit for and continue for
		seen = 0
		for each kv in m
			if( kv.value = 20 ) then continue for
			if( kv.value = 99 ) then exit for
			seen += 1
		next
		assert_( seen = 2 )

		'' a map with a removed entry must not yield the tombstone
		m.Remove( "b" )
		seen = 0
		for each kv in m
			seen += 1
		next
		assert_( seen = 2 )

		'' nested iteration over the same map
		dim as long pairs = 0
		for each x in m
			for each y in m
				pairs += 1
			next
		next
		assert_( pairs = 4 )
	end scope

	'' ==================================================== key and value types

	scope
		'' integer keys
		dim mi as Map( of long, string )
		mi.Put( 1, "one" )
		mi.Put( 2, "two" )
		assert_( mi[ 1 ] = "one" )
		assert_( mi.Count( ) = 2 )

		'' string values, overwritten
		mi.Put( 1, "uno" )
		assert_( mi[ 1 ] = "uno" )
		assert_( mi.Count( ) = 2 )

		'' double keys, including the +0.0 / -0.0 case: they compare EQUAL, so
		'' they must hash equal or the map loses the entry
		dim md as Map( of double, long )
		md.Put( 0.0, 1 )
		assert_( md.Contains( -0.0 ) )
		assert_( md.Count( ) = 1 )
		md.Put( 1.5, 2 )
		assert_( md.Count( ) = 2 )
		assert_( md[ 1.5 ] = 2 )

		'' a user-defined key type through the HashOf extension point
		dim mp as Map( of PairKey, string )
		dim as PairKey k1, k2
		k1.a = 1 : k1.b = 2
		k2.a = 1 : k2.b = 2                     '' equal to k1, different object
		mp.Put( k1, "first" )
		assert_( mp.Contains( k2 ) )            '' equal keys must find each other
		assert_( mp[ k2 ] = "first" )
		assert_( mp.Count( ) = 1 )

		k2.b = 3
		assert_( mp.Contains( k2 ) = false )
		mp.Put( k2, "second" )
		assert_( mp.Count( ) = 2 )

		'' many user keys, forcing rehashes with a custom hash
		dim mm as Map( of PairKey, long )
		for i as long = 0 to 499
			dim as PairKey k
			k.a = i : k.b = i * 2
			mm.Put( k, i )
		next
		assert_( mm.Count( ) = 500 )
		dim as boolean ok = true
		for i as long = 0 to 499
			dim as PairKey k
			k.a = i : k.b = i * 2
			if( mm.Contains( k ) = false ) then ok = false
		next
		assert_( ok )

		'' a value that is itself a container
		dim mc as Map( of string, Array( of long ) )
		dim inner as Array( of long )
		inner.Push( 1 ) : inner.Push( 2 )
		mc.Put( "nums", inner )
		assert_( mc.Count( ) = 1 )
		assert_( mc[ "nums" ].Count( ) = 2 )
		inner.Push( 3 )
		assert_( mc[ "nums" ].Count( ) = 2 )    '' copied in, not aliased
		mc[ "nums" ].Push( 9 )
		assert_( mc[ "nums" ].Count( ) = 3 )
	end scope

	'' ==================================================== copy and assignment

	scope
		dim a as Map( of string, long )
		a.Put( "x", 1 )
		a.Put( "y", 2 )

		dim b as Map( of string, long ) = a
		assert_( b.Count( ) = 2 )

		'' writing the copy must not touch the original
		b.Put( "x", 99 )
		b.Put( "z", 3 )
		assert_( a[ "x" ] = 1 )
		assert_( a.Count( ) = 2 )

		'' ...and writing the original must not touch the copy
		a.Put( "y", 88 )
		assert_( b[ "y" ] = 2 )

		'' assignment: same both ways, and the old contents go
		dim c as Map( of string, long )
		c.Put( "gone", 1 )
		c = a
		assert_( c.Count( ) = 2 )
		assert_( c.Contains( "gone" ) = false )
		c.Put( "x", 77 )
		assert_( a[ "x" ] = 1 )

		'' assigning an empty map over a full one empties it
		dim d as Map( of string, long )
		c = d
		assert_( c.Count( ) = 0 )
		assert_( a.Count( ) = 2 )
	end scope

	'' ==================================================== destructor balance

	liveCounted = 0

	scope
		dim m as Map( of long, Counted )

		for i as long = 0 to 199
			dim as Counted c = Counted( i )
			m.Put( i, c )                       '' forces several rehashes
		next
		assert_( m.Count( ) = 200 )

		for i as long = 0 to 199 step 2
			m.Remove( i )
		next
		assert_( m.Count( ) = 100 )

		dim m2 as Map( of long, Counted ) = m   '' deep copy
		assert_( m2.Count( ) = 100 )

		m2.Clear( )
		assert_( m2.Count( ) = 0 )
	end scope

	assert_( liveCounted = 0 )
