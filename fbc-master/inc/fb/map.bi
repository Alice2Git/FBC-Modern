'' fb/map.bi -- FB.Map( of TK, TV ), an open-addressed hash map
''
'' RFC-0004 §3 (there called Dictionary).  Replaces CDicObj.inc, which obtains a
'' dictionary by instantiating Scripting.Dictionary over COM -- Windows-only,
'' CoInitialize per instance, every key and value a VARIANT, every lookup a
'' late-bound IDispatch call.
''
''     dim ages as FB.Map( of string, long )
''     ages.Put( "ada", 36 )
''     if ages.Contains( "ada" ) then print ages[ "ada" ]
''
''     for each kv in ages
''         print kv.key, kv.value
''     next
''
'' READING vs WRITING -- the most important thing on this page.
''
''     m[ k ]        INSERTS a default-constructed TV if k is absent.
''     m.TryGet      does not.
''     m.Contains    does not.
''
'' 'm[ k ] += 1' just working is why the indexer inserts, and 'if m[ k ] = 0'
'' silently growing the map is the price.  Every language has this argument and
'' none has won it; C# splits it the same way.  Use TryGet or Contains to READ.
''
'' THE HASH CONTRACT is in fb/hash.bi: 'FB.HashOf( k )' must resolve and 'k = k'
'' must compare, and EQUAL KEYS MUST HASH EQUAL.
''
'' IMPLEMENTATION.  Open addressing with linear probing, power-of-two capacity,
'' tombstones on removal, load factor 0.75, rehash doubles.  Open addressing is
'' chosen over chaining for one allocation instead of one per entry, which
'' matters more in a language with no garbage collector.
''
'' ITERATION ORDER IS UNSPECIFIED and changes across insertions.  It is not
'' randomised per process -- that is a hash-flooding defence FreeBASIC has no
'' threat model for, and stability within one unmodified map is more useful when
'' debugging.

#pragma once

#include once "fb/hash.bi"
#include once "fb/array.bi"

namespace FB

const MAP_MIN_CAPACITY as long = 8

'' slot states
const MAP_EMPTY as ubyte = 0
const MAP_USED  as ubyte = 1
const MAP_TOMB  as ubyte = 2

'' What iteration yields.  A pair rather than two loop variables because
'' destructuring syntax does not exist yet.
type KeyValuePair( of TK, TV )
	as TK key
	as TV value
end type

type MapIterator( of TK, TV )
	as any ptr src
	as long slot
	declare function IsValid( ) as boolean
	declare function Value( ) as KeyValuePair( of TK, TV )
	declare sub MoveNext( )
end type

type Map( of TK, TV )
	as TK keys_( any )
	as TV vals_( any )
	as ubyte state( any )
	as long num                         '' live entries
	as long used                        '' live + tombstones, for the load factor

	declare function Count( ) as long
	declare function IsEmpty( ) as boolean
	declare function Capacity( ) as long

	declare sub Reserve( byval n as long )
	declare sub Clear( )

	declare function FindSlot( byref k as TK ) as long
	declare function Put( byref k as TK, byref v as TV ) as boolean
	declare function Add( byref k as TK, byref v as TV ) as boolean
	declare function Contains( byref k as TK ) as boolean
	declare function TryGet( byref k as TK, byref outv as TV ) as boolean
	declare function Remove( byref k as TK ) as boolean
	declare operator [] ( byref k as TK ) byref as TV

	declare function Keys( ) as Array( of TK )
	declare function Values( ) as Array( of TV )
	declare function GetIterator( ) as MapIterator( of TK, TV )
end type

function Map( of TK, TV ).Count( ) as long
	return this.num
end function

function Map( of TK, TV ).IsEmpty( ) as boolean
	return this.num = 0
end function

function Map( of TK, TV ).Capacity( ) as long
	return ubound( this.state ) - lbound( this.state ) + 1
end function

'' The slot holding k, or -1.
''
'' Linear probing stops at the first EMPTY slot: a tombstone means "keep going",
'' which is the whole reason removal cannot simply blank a slot -- doing so
'' would cut the probe chain and hide every key that had collided past it.
function Map( of TK, TV ).FindSlot( byref k as TK ) as long
	dim as long cap = this.Capacity( )
	if( cap = 0 ) then
		return -1
	end if

	dim as long mask = cap - 1
	dim as long i = cast( long, HashOf( k ) and cast( ulongint, mask ) )

	for probe as long = 0 to cap-1
		select case this.state( i )
		case MAP_EMPTY
			return -1
		case MAP_USED
			if( this.keys_( i ) = k ) then
				return i
			end if
		end select

		i = (i + 1) and mask
	next

	return -1
end function

'' Grow to at least n entries' worth of slots, keeping the load factor under
'' 0.75.  Rehashing also drops every tombstone, which is what stops a
'' put/remove loop from filling the table with them.
sub Map( of TK, TV ).Reserve( byval n as long )
	dim as long cap = this.Capacity( )
	dim as long want = MAP_MIN_CAPACITY

	while( (want * 3) \ 4 < n )
		want *= 2
	wend

	if( want <= cap ) then
		exit sub
	end if

	'' keep the old contents while the new tables are built
	dim as long oldcap = cap
	dim oldkeys( any ) as TK
	dim oldvals( any ) as TV
	dim oldstate( any ) as ubyte

	if( oldcap > 0 ) then
		redim oldkeys( 0 to oldcap-1 )
		redim oldvals( 0 to oldcap-1 )
		redim oldstate( 0 to oldcap-1 )
		for i as long = 0 to oldcap-1
			oldstate( i ) = this.state( i )
			if( this.state( i ) = MAP_USED ) then
				oldkeys( i ) = this.keys_( i )
				oldvals( i ) = this.vals_( i )
			end if
		next
	end if

	redim this.keys_( 0 to want-1 )
	redim this.vals_( 0 to want-1 )
	redim this.state( 0 to want-1 )

	this.num = 0
	this.used = 0

	for i as long = 0 to oldcap-1
		if( oldstate( i ) = MAP_USED ) then
			this.Put( oldkeys( i ), oldvals( i ) )
		end if
	next
end sub

sub Map( of TK, TV ).Clear( )
	dim as TK blankk
	dim as TV blankv

	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = MAP_USED ) then
			this.keys_( i ) = blankk
			this.vals_( i ) = blankv
		end if
		this.state( i ) = MAP_EMPTY
	next

	this.num = 0
	this.used = 0
end sub

'' Insert or overwrite.  Returns TRUE if the key was new.
function Map( of TK, TV ).Put( byref k as TK, byref v as TV ) as boolean
	'' Copy both before any rehash: k or v may point INTO this map --
	'' 'm.Put( m.Keys( )[ 0 ], m[ someKey ] )' is legal -- and Reserve
	'' reallocates the storage they point at.
	dim as TK kk = k
	dim as TV vv = v

	if( (this.used + 1) * 4 >= this.Capacity( ) * 3 ) then
		this.Reserve( this.num + 1 )
	end if

	dim as long cap = this.Capacity( )
	dim as long mask = cap - 1
	dim as long i = cast( long, HashOf( kk ) and cast( ulongint, mask ) )
	dim as long firsttomb = -1

	for probe as long = 0 to cap-1
		select case this.state( i )
		case MAP_EMPTY
			'' a tombstone seen earlier is a better home: it shortens the chain
			if( firsttomb >= 0 ) then
				i = firsttomb
			else
				this.used += 1
			end if
			this.keys_( i ) = kk
			this.vals_( i ) = vv
			this.state( i ) = MAP_USED
			this.num += 1
			return true

		case MAP_TOMB
			if( firsttomb < 0 ) then
				firsttomb = i
			end if

		case MAP_USED
			if( this.keys_( i ) = kk ) then
				this.vals_( i ) = vv
				return false
			end if
		end select

		i = (i + 1) and mask
	next

	return false
end function

'' Insert only if absent.  Returns FALSE if the key was already there, and does
'' NOT overwrite -- that is the difference from Put.
function Map( of TK, TV ).Add( byref k as TK, byref v as TV ) as boolean
	if( this.FindSlot( k ) >= 0 ) then
		return false
	end if
	this.Put( k, v )
	return true
end function

function Map( of TK, TV ).Contains( byref k as TK ) as boolean
	return this.FindSlot( k ) >= 0
end function

'' Read without inserting.  Leaves outv alone on a miss.
function Map( of TK, TV ).TryGet( byref k as TK, byref outv as TV ) as boolean
	dim as long i = this.FindSlot( k )
	if( i < 0 ) then
		return false
	end if
	outv = this.vals_( i )
	return true
end function

'' Returns TRUE if something was removed.  The slot becomes a TOMBSTONE, not
'' EMPTY -- see FindSlot.
function Map( of TK, TV ).Remove( byref k as TK ) as boolean
	dim as long i = this.FindSlot( k )
	if( i < 0 ) then
		return false
	end if

	dim as TK blankk
	dim as TV blankv
	this.keys_( i ) = blankk
	this.vals_( i ) = blankv
	this.state( i ) = MAP_TOMB
	this.num -= 1

	return true
end function

'' INSERTS a default-constructed TV when k is absent.  See the header.
operator Map( of TK, TV ).[] ( byref k as TK ) byref as TV
	dim as long i = this.FindSlot( k )

	if( i < 0 ) then
		dim as TV blank
		this.Put( k, blank )
		i = this.FindSlot( k )
	end if

	return this.vals_( i )
end operator

function Map( of TK, TV ).Keys( ) as Array( of TK )
	dim r as Array( of TK )
	r.Reserve( this.num )
	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = MAP_USED ) then
			r.Push( this.keys_( i ) )
		end if
	next
	return r
end function

function Map( of TK, TV ).Values( ) as Array( of TV )
	dim r as Array( of TV )
	r.Reserve( this.num )
	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = MAP_USED ) then
			r.Push( this.vals_( i ) )
		end if
	next
	return r
end function

function Map( of TK, TV ).GetIterator( ) as MapIterator( of TK, TV )
	dim it as MapIterator( of TK, TV )
	it.src = @this
	it.slot = 0

	'' land on the first live slot, or past the end for an empty map
	dim as long cap = this.Capacity( )
	while( (it.slot < cap) andalso (this.state( it.slot ) <> MAP_USED) )
		it.slot += 1
	wend

	return it
end function

function MapIterator( of TK, TV ).IsValid( ) as boolean
	dim as Map( of TK, TV ) ptr m = cptr( Map( of TK, TV ) ptr, this.src )
	return this.slot < m->Capacity( )
end function

'' By value, not byref: the pair is assembled here and does not live in the map.
'' Assigning to it therefore changes nothing, which is why there is no byref
'' binding for a map -- use m[ k ] to write.
function MapIterator( of TK, TV ).Value( ) as KeyValuePair( of TK, TV )
	dim as Map( of TK, TV ) ptr m = cptr( Map( of TK, TV ) ptr, this.src )
	dim r as KeyValuePair( of TK, TV )
	r.key = m->keys_( this.slot )
	r.value = m->vals_( this.slot )
	return r
end function

sub MapIterator( of TK, TV ).MoveNext( )
	dim as Map( of TK, TV ) ptr m = cptr( Map( of TK, TV ) ptr, this.src )
	dim as long cap = m->Capacity( )

	this.slot += 1
	while( (this.slot < cap) andalso (m->state( this.slot ) <> MAP_USED) )
		this.slot += 1
	wend
end sub

end namespace
