'' fb/array.bi -- FB.Array( of T ), a growable array
''
'' RFC-0004 §2 (there called Vector).  Replaces the 'redim preserve' append
'' idiom, which reallocates and copies on EVERY call and is therefore O(n²) over
'' a loop:
''
''     redim preserve arr( 0 to ubound( arr ) + 1 )     '' don't
''     arr( ubound( arr ) ) = newItem
''
''     dim v as FB.Array( of string )                   '' do
''     v.Push( "ada" )
''
'' INDICES ARE ZERO-BASED.  This is a deliberate break with 'dim arr(1 to 10)'
'' BASIC tradition, taken because Count and index arithmetic are otherwise a
'' permanent source of off-by-one, and because every other language's growable
'' array is zero-based.  It is stated loudly rather than hidden.
''
'' STORAGE.  The elements live in an ordinary FreeBASIC dynamic array, redim'd
'' only when the capacity doubles -- never per push.  That keeps the append
'' amortised O(1) while letting the language do element construction, copying
'' and destruction: a deep copy, an assignment and a destructor all fall out for
'' free, and there is no manual memory to get wrong.  Measured before it was
'' chosen: a dynamic array field inside a generic redims correctly, copies
'' deeply on construction and on assignment, and carries T's constructors.
''
'' OWNERSHIP.  The array owns its storage.  Copy and assignment are DEEP, which
'' is the only rule consistent with FreeBASIC's value semantics for UDTs, and is
'' expensive -- there is no move constructor in the language to avoid it.  Pass
'' containers BYREF where it matters.  An Array( of T ptr ) frees the array, not
'' the pointees.

#pragma once

namespace FB

'' The default growth: doubling, from 8.  Doubling gives amortised O(1) append;
'' 1.5x would waste less and is not worth the arithmetic here.  Reserve( ) exists
'' for anyone who cares about the exact allocation.
const ARRAY_MIN_CAPACITY as long = 8

'' ----------------------------------------------------------------- iterator
''
'' RFC-0002: IsValid / Value / MoveNext, so 'for each' works.  Value( ) returns
'' BYREF, so 'for each byref v in a' can modify elements in place.
''
'' Holds a pointer to the array, not a copy of it -- an iterator is created per
'' loop and must not deep-copy the container.
type ArrayIterator( of T )
	as any ptr src
	as long idx
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type

type Array( of T )
	as T items( any )
	as long num

	declare function Count( ) as long
	declare function Capacity( ) as long
	declare function IsEmpty( ) as boolean

	declare operator [] ( byval i as long ) byref as T
	declare function At( byval i as long ) byref as T

	declare sub Push( byref v as T )
	declare function Pop( ) as T
	declare sub Insert( byval i as long, byref v as T )
	declare sub Remove( byval i as long )
	declare sub RemoveSwap( byval i as long )
	declare sub Clear( )
	declare sub Reserve( byval n as long )
	declare sub Shrink( )
	declare function GetIterator( ) as ArrayIterator( of T )
end type

function ArrayIterator( of T ).IsValid( ) as boolean
	dim as Array( of T ) ptr a = cptr( Array( of T ) ptr, this.src )
	return this.idx < a->num
end function

function ArrayIterator( of T ).Value( ) byref as T
	dim as Array( of T ) ptr a = cptr( Array( of T ) ptr, this.src )
	return a->items( this.idx )
end function

sub ArrayIterator( of T ).MoveNext( )
	this.idx += 1
end sub

function Array( of T ).Count( ) as long
	return this.num
end function

function Array( of T ).Capacity( ) as long
	return ubound( this.items ) - lbound( this.items ) + 1
end function

function Array( of T ).IsEmpty( ) as boolean
	return this.num = 0
end function

'' Grow to at least n slots.  Never shrinks -- Shrink( ) is explicit, because a
'' push/pop loop sitting on a capacity boundary would otherwise thrash.
sub Array( of T ).Reserve( byval n as long )
	if( n <= this.Capacity( ) ) then
		exit sub
	end if

	dim as long cap = this.Capacity( )
	if( cap < ARRAY_MIN_CAPACITY ) then
		cap = ARRAY_MIN_CAPACITY
	end if
	while( cap < n )
		cap *= 2
	wend

	redim preserve this.items( 0 to cap-1 )
end sub

sub Array( of T ).Shrink( )
	if( this.num = 0 ) then
		erase this.items
		exit sub
	end if
	if( this.num = this.Capacity( ) ) then
		exit sub
	end if
	redim preserve this.items( 0 to this.num-1 )
end sub

operator Array( of T ).[] ( byval i as long ) byref as T
	return this.items( i )
end operator

function Array( of T ).At( byval i as long ) byref as T
	return this.items( i )
end function

sub Array( of T ).Push( byref v as T )
	this.Reserve( this.num + 1 )
	this.items( this.num ) = v
	this.num += 1
end sub

'' Remove and return the last element.  The slot is left alone rather than
'' cleared: for a T with a destructor the language destroys it when the array
'' does, and clearing here would cost a construction per pop.
function Array( of T ).Pop( ) as T
	dim as T r
	if( this.num = 0 ) then
		return r
	end if
	this.num -= 1
	r = this.items( this.num )
	return r
end function

sub Array( of T ).Insert( byval i as long, byref v as T )
	if( (i < 0) orelse (i > this.num) ) then
		exit sub
	end if

	'' Reserve FIRST: it may redim, and a byref v pointing INTO this array
	'' would then dangle.  Copying v before the shift avoids that entirely, and
	'' also makes 'a.Insert( 0, a[ 3 ] )' mean what it looks like.
	dim as T tmp = v

	this.Reserve( this.num + 1 )

	for k as long = this.num to i+1 step -1
		this.items( k ) = this.items( k-1 )
	next

	this.items( i ) = tmp
	this.num += 1
end sub

'' Order-preserving removal, O(n).
sub Array( of T ).Remove( byval i as long )
	if( (i < 0) orelse (i >= this.num) ) then
		exit sub
	end if

	for k as long = i to this.num-2
		this.items( k ) = this.items( k+1 )
	next

	this.num -= 1
end sub

'' O(1) removal that does NOT preserve order: the last element moves into the
'' hole.  Named so the caller cannot pick it by accident.
sub Array( of T ).RemoveSwap( byval i as long )
	if( (i < 0) orelse (i >= this.num) ) then
		exit sub
	end if

	this.num -= 1
	if( i <> this.num ) then
		this.items( i ) = this.items( this.num )
	end if
end sub

'' Drops every element but keeps the capacity, so a clear-and-refill loop does
'' not reallocate.  The slots are reset so that a T holding a resource -- a
'' string, another container -- releases it now rather than at the array's
'' destruction.
sub Array( of T ).Clear( )
	dim as T blank
	for k as long = 0 to this.num-1
		this.items( k ) = blank
	next
	this.num = 0
end sub

'' ------------------------------------------------- free generic procedures
''
'' IndexOf, Contains and Sort are NOT members, and that is not a style choice.
''
'' Every member body of a generic is replayed for every instantiation, whether
'' or not it is ever called -- there is no lazy member instantiation.  So a
'' member that needs '=' on T makes the WHOLE TYPE unusable for any T without
'' one, and a member that needs '<' does the same.  As members, these three made
'' Array( of Array( of long ) ) fail to instantiate:
''
''     array.bi(224) error 20: Type mismatch
''       in instantiation of 'Array( of Array( of long ) )'
''
'' A generic PROCEDURE is instantiated only where it is called, so the
'' requirement lands on the call site that actually needs it.  T is inferred
'' from the nested Array( of T ) position.

'' Requires '=' on T.  Returns -1 when absent, which is why the result is signed
'' and why Contains( ) exists for the common case.
function IndexOf( of T )( byref a as Array( of T ), byref v as T ) as long
	for k as long = 0 to a.num-1
		if( a.items( k ) = v ) then
			return k
		end if
	next
	return -1
end function

function Contains( of T )( byref a as Array( of T ), byref v as T ) as boolean
	return IndexOf( a, v ) >= 0
end function

'' Ascending sort, requiring '<' on T.
''
'' Insertion sort over a gap sequence -- Shell sort with Ciura's gaps.  Chosen
'' over quicksort because it needs no recursion, no stack, no pivot policy and no
'' separate small-range cutoff, is in-place and branch-simple, and moves elements
'' with plain assignment so a T with a copy constructor behaves.  It is not
'' O(n log n) in the worst case; it is about O(n^1.3) in practice, which is the
'' honest claim.  A comparer parameter needs procedure pointers over a generic
'' parameter and is left for later.
sub Sort( of T )( byref a as Array( of T ) )
	static as long gaps( 0 to 7 ) = { 701, 301, 132, 57, 23, 10, 4, 1 }

	for g as long = 0 to 7
		dim as long gap = gaps( g )
		if( gap >= a.num ) then
			continue for
		end if

		for i as long = gap to a.num-1
			dim as T tmp = a.items( i )
			dim as long j = i

			while( j >= gap )
				if( tmp < a.items( j-gap ) ) then
					a.items( j ) = a.items( j-gap )
					j -= gap
				else
					exit while
				end if
			wend

			a.items( j ) = tmp
		next
	next
end sub

'' Apply f to every element, in order, passing each BYREF so it can be modified
'' in place.
''
'' The reason this exists as a generic rather than taking a procedure pointer:
'' a CAPTURING lambda is a closure object, not a procptr, so a procptr parameter
'' could not accept one. 'of F' accepts either kind --
''
''     dim as longint total = 0
''     ForEach( nums, sub[ byref total ]( byref v as long ) : total += v : end sub )
''
'' -- and a non-capturing lambda or a plain '@proc' still work, because calling
'' through a generic parameter is just 'f( x )' either way.
sub ForEach( of T, F )( byref a as Array( of T ), byref f as F )
	for i as long = 0 to a.num-1
		f( a.items( i ) )
	next
end sub

function Array( of T ).GetIterator( ) as ArrayIterator( of T )
	dim it as ArrayIterator( of T )
	it.src = @this
	it.idx = 0
	return it
end function

end namespace
