'' fb/set.bi -- FB.Set( of T ), a hash set
''
'' RFC-0004 §5.  A Map with the value machinery removed rather than a wrapper
'' around one, so a Set costs one slot per element instead of two.
''
''     dim seen as FB.Set( of long )
''     if seen.Add( 42 ) then print "first time"
''
''     for each x in seen
''         print x
''     next
''
'' Add returns FALSE when the element was already present, which is what makes
'' 'if seen.Add( x ) then' the natural spelling of "process each thing once".
''
'' THE HASH CONTRACT is in fb/hash.bi: 'FB.HashOf( v )' must resolve and 'v = v'
'' must compare, and EQUAL ELEMENTS MUST HASH EQUAL.
''
'' Same implementation as Map -- open addressing, linear probing, power-of-two
'' capacity, tombstones on removal, load factor 0.75 -- and the same unspecified,
'' unstable iteration order.

#pragma once

#include once "fb/hash.bi"
#include once "fb/array.bi"

namespace FB

const SET_MIN_CAPACITY as long = 8

const SET_EMPTY as ubyte = 0
const SET_USED  as ubyte = 1
const SET_TOMB  as ubyte = 2

type SetIterator( of T )
	as any ptr src
	as long slot
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type

type Set( of T )
	as T elems( any )
	as ubyte state( any )
	as long num                         '' live elements
	as long used                        '' live + tombstones, for the load factor

	declare function Count( ) as long
	declare function IsEmpty( ) as boolean
	declare function Capacity( ) as long

	declare sub Reserve( byval n as long )
	declare sub Clear( )

	declare function FindSlot( byref v as T ) as long
	declare function Add( byref v as T ) as boolean
	declare function Contains( byref v as T ) as boolean
	declare function Remove( byref v as T ) as boolean

	declare sub UnionWith( byref other as Set( of T ) )
	declare sub IntersectWith( byref other as Set( of T ) )
	declare sub ExceptWith( byref other as Set( of T ) )

	declare function Items( ) as Array( of T )
	declare function GetIterator( ) as SetIterator( of T )
end type

function Set( of T ).Count( ) as long
	return this.num
end function

function Set( of T ).IsEmpty( ) as boolean
	return this.num = 0
end function

function Set( of T ).Capacity( ) as long
	return ubound( this.state ) - lbound( this.state ) + 1
end function

'' The slot holding v, or -1.  Probing stops at the first EMPTY slot; a
'' tombstone means "keep going", which is why removal cannot blank a slot -- it
'' would cut the chain and hide everything that collided past it.
function Set( of T ).FindSlot( byref v as T ) as long
	dim as long cap = this.Capacity( )
	if( cap = 0 ) then
		return -1
	end if

	dim as long mask = cap - 1
	dim as long i = cast( long, HashOf( v ) and cast( ulongint, mask ) )

	for probe as long = 0 to cap-1
		select case this.state( i )
		case SET_EMPTY
			return -1
		case SET_USED
			if( this.elems( i ) = v ) then
				return i
			end if
		end select

		i = (i + 1) and mask
	next

	return -1
end function

'' Grow to hold at least n elements under a 0.75 load factor.  Rehashing drops
'' every tombstone, which is what stops an add/remove loop filling the table
'' with them.
sub Set( of T ).Reserve( byval n as long )
	dim as long cap = this.Capacity( )
	dim as long want = SET_MIN_CAPACITY

	while( (want * 3) \ 4 < n )
		want *= 2
	wend

	if( want <= cap ) then
		exit sub
	end if

	dim as long oldcap = cap
	dim oldelems( any ) as T
	dim oldstate( any ) as ubyte

	if( oldcap > 0 ) then
		redim oldelems( 0 to oldcap-1 )
		redim oldstate( 0 to oldcap-1 )
		for i as long = 0 to oldcap-1
			oldstate( i ) = this.state( i )
			if( this.state( i ) = SET_USED ) then
				oldelems( i ) = this.elems( i )
			end if
		next
	end if

	redim this.elems( 0 to want-1 )
	redim this.state( 0 to want-1 )

	this.num = 0
	this.used = 0

	for i as long = 0 to oldcap-1
		if( oldstate( i ) = SET_USED ) then
			this.Add( oldelems( i ) )
		end if
	next
end sub

sub Set( of T ).Clear( )
	dim as T blank

	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = SET_USED ) then
			this.elems( i ) = blank
		end if
		this.state( i ) = SET_EMPTY
	next

	this.num = 0
	this.used = 0
end sub

'' Insert.  Returns FALSE if the element was already present, which is the
'' "have I seen this before" idiom.
function Set( of T ).Add( byref v as T ) as boolean
	'' Copy before any rehash: v may point INTO this set -- Reserve( ) calls
	'' Add( ) with its own old storage -- and the reserve reallocates it.
	dim as T vv = v

	if( (this.used + 1) * 4 >= this.Capacity( ) * 3 ) then
		this.Reserve( this.num + 1 )
	end if

	dim as long cap = this.Capacity( )
	dim as long mask = cap - 1
	dim as long i = cast( long, HashOf( vv ) and cast( ulongint, mask ) )
	dim as long firsttomb = -1

	for probe as long = 0 to cap-1
		select case this.state( i )
		case SET_EMPTY
			'' a tombstone seen earlier is a better home: it shortens the chain
			if( firsttomb >= 0 ) then
				i = firsttomb
			else
				this.used += 1
			end if
			this.elems( i ) = vv
			this.state( i ) = SET_USED
			this.num += 1
			return true

		case SET_TOMB
			if( firsttomb < 0 ) then
				firsttomb = i
			end if

		case SET_USED
			if( this.elems( i ) = vv ) then
				return false
			end if
		end select

		i = (i + 1) and mask
	next

	return false
end function

function Set( of T ).Contains( byref v as T ) as boolean
	return this.FindSlot( v ) >= 0
end function

'' Returns TRUE if something was removed.  The slot becomes a TOMBSTONE.
function Set( of T ).Remove( byref v as T ) as boolean
	dim as long i = this.FindSlot( v )
	if( i < 0 ) then
		return false
	end if

	dim as T blank
	this.elems( i ) = blank
	this.state( i ) = SET_TOMB
	this.num -= 1

	return true
end function

'' this = this OR other
sub Set( of T ).UnionWith( byref other as Set( of T ) )
	for i as long = 0 to other.Capacity( )-1
		if( other.state( i ) = SET_USED ) then
			this.Add( other.elems( i ) )
		end if
	next
end sub

'' this = this AND other.
''
'' Collected first, then removed: removing while walking this set's own slots
'' would leave tombstones in the middle of a chain being probed.
sub Set( of T ).IntersectWith( byref other as Set( of T ) )
	dim doomed as Array( of T )

	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = SET_USED ) then
			if( other.Contains( this.elems( i ) ) = false ) then
				doomed.Push( this.elems( i ) )
			end if
		end if
	next

	for i as long = 0 to doomed.Count( )-1
		this.Remove( doomed[ i ] )
	next
end sub

'' this = this AND NOT other
sub Set( of T ).ExceptWith( byref other as Set( of T ) )
	'' Walk the SMALLER side where possible.  Removing 'other's elements one by
	'' one is O(|other|); scanning this set is O(capacity).
	for i as long = 0 to other.Capacity( )-1
		if( other.state( i ) = SET_USED ) then
			this.Remove( other.elems( i ) )
		end if
	next
end sub

'' A snapshot, in the set's own unspecified order.
function Set( of T ).Items( ) as Array( of T )
	dim r as Array( of T )
	r.Reserve( this.num )
	for i as long = 0 to this.Capacity( )-1
		if( this.state( i ) = SET_USED ) then
			r.Push( this.elems( i ) )
		end if
	next
	return r
end function

function Set( of T ).GetIterator( ) as SetIterator( of T )
	dim it as SetIterator( of T )
	it.src = @this
	it.slot = 0

	dim as long cap = this.Capacity( )
	while( (it.slot < cap) andalso (this.state( it.slot ) <> SET_USED) )
		it.slot += 1
	wend

	return it
end function

function SetIterator( of T ).IsValid( ) as boolean
	dim as Set( of T ) ptr s = cptr( Set( of T ) ptr, this.src )
	return this.slot < s->Capacity( )
end function

'' BYREF, so 'for each byref' compiles -- but an element of a hash set must not
'' be modified in place: changing it changes its hash and it can never be found
'' again.  Remove and re-Add instead.
function SetIterator( of T ).Value( ) byref as T
	dim as Set( of T ) ptr s = cptr( Set( of T ) ptr, this.src )
	return s->elems( this.slot )
end function

sub SetIterator( of T ).MoveNext( )
	dim as Set( of T ) ptr s = cptr( Set( of T ) ptr, this.src )
	dim as long cap = s->Capacity( )

	this.slot += 1
	while( (this.slot < cap) andalso (s->state( this.slot ) <> SET_USED) )
		this.slot += 1
	wend
end sub

end namespace
