' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.LinkedList( of T ) -- exhaustive.
''
'' Every declared member, every state, both ends, deep copy and assignment
'' independence in both directions, self-assignment, destructor balance, element
'' types including a nested container, and FOR EACH.
''
'' This one carries RAW NODE POINTERS rather than a dynamic array, so its copy
'' constructor, LET and destructor are hand-written -- which makes the copy and
'' lifetime sections here load-bearing rather than a formality.  A shallow copy
'' would leave two lists sharing one chain and double-free it.

#include once "fb/linkedlist.bi"
#include once "fb/array.bi"
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

	'' ==================================================== the empty state

	scope
		dim q as LinkedList( of long )

		assert_( q.Count( ) = 0 )
		assert_( q.IsEmpty( ) )

		'' popping an empty list returns a default-constructed T rather than
		'' dereferencing a null head
		assert_( q.PopFront( ) = 0 )
		assert_( q.PopBack( ) = 0 )
		assert_( q.Count( ) = 0 )

		'' Front/Back on an empty list return a reference to a blank
		assert_( q.Front( ) = 0 )
		assert_( q.Back( ) = 0 )

		q.Clear( )
		assert_( q.Count( ) = 0 )

		dim as long n = 0
		for each v in q
			n += 1
		next
		assert_( n = 0 )
	end scope

	'' ==================================================== one element

	scope
		dim q as LinkedList( of long )
		q.PushBack( 7 )

		assert_( q.Count( ) = 1 )
		assert_( q.IsEmpty( ) = false )
		assert_( q.Front( ) = 7 )
		assert_( q.Back( ) = 7 )        '' head and tail are the same node

		dim as long n = 0
		for each v in q
			n += 1
		next
		assert_( n = 1 )

		'' removing the only element must clear BOTH ends, or the next push
		'' links onto a freed node
		assert_( q.PopFront( ) = 7 )
		assert_( q.Count( ) = 0 )
		q.PushBack( 8 )
		assert_( q.Front( ) = 8 )
		assert_( q.Back( ) = 8 )
		assert_( q.PopBack( ) = 8 )
		assert_( q.Count( ) = 0 )
		q.PushFront( 9 )
		assert_( q.Front( ) = 9 )
		assert_( q.Back( ) = 9 )
	end scope

	'' ==================================================== both ends

	scope
		dim q as LinkedList( of string )

		q.PushBack( "b" )
		q.PushFront( "a" )
		q.PushBack( "c" )               '' a b c

		assert_( q.Count( ) = 3 )
		assert_( q.Front( ) = "a" )
		assert_( q.Back( ) = "c" )

		dim cat as string = ""
		for each s in q
			cat += s
		next
		assert_( cat = "abc" )

		assert_( q.PopFront( ) = "a" )
		assert_( q.PopBack( ) = "c" )
		assert_( q.Count( ) = 1 )
		assert_( q.Front( ) = "b" )
		assert_( q.Back( ) = "b" )

		'' Front and Back are byref, so they can be read through repeatedly
		assert_( q.Front( ) = q.Back( ) )
	end scope

	'' ==================================================== queue and stack use

	scope
		'' FIFO
		dim q as LinkedList( of long )
		for i as long = 1 to 5
			q.PushBack( i )
		next
		dim as boolean ok = true
		for i as long = 1 to 5
			if( q.PopFront( ) <> i ) then ok = false
		next
		assert_( ok )
		assert_( q.IsEmpty( ) )

		'' LIFO
		for i as long = 1 to 5
			q.PushBack( i )
		next
		ok = true
		for i as long = 5 to 1 step -1
			if( q.PopBack( ) <> i ) then ok = false
		next
		assert_( ok )
		assert_( q.IsEmpty( ) )

		'' front insertion reverses
		for i as long = 1 to 5
			q.PushFront( i )
		next
		assert_( q.Front( ) = 5 )
		assert_( q.Back( ) = 1 )

		'' drain from alternating ends
		assert_( q.PopFront( ) = 5 )
		assert_( q.PopBack( ) = 1 )
		assert_( q.PopFront( ) = 4 )
		assert_( q.PopBack( ) = 2 )
		assert_( q.PopFront( ) = 3 )
		assert_( q.IsEmpty( ) )

		'' and it is reusable afterwards
		q.PushBack( 100 )
		assert_( q.Count( ) = 1 )
		assert_( q.Front( ) = 100 )
	end scope

	'' ==================================================== pushing its own element
	''
	'' 'q.PushFront( q.Back( ) )' passes a reference to a node this call is about
	'' to link in front of.  The value has to be copied before the node is
	'' created, or the argument refers into a list being restructured.

	scope
		dim q as LinkedList( of long )
		q.PushBack( 1 )
		q.PushBack( 2 )

		q.PushFront( q.Back( ) )
		assert_( q.Count( ) = 3 )
		assert_( q.Front( ) = 2 )
		assert_( q.Back( ) = 2 )

		q.PushBack( q.Front( ) )
		assert_( q.Count( ) = 4 )
		assert_( q.Back( ) = 2 )
	end scope

	'' ==================================================== many elements

	scope
		dim q as LinkedList( of long )

		for i as long = 0 to 9999
			q.PushBack( i )
		next
		assert_( q.Count( ) = 10000 )
		assert_( q.Front( ) = 0 )
		assert_( q.Back( ) = 9999 )

		'' the chain is intact end to end, and in order
		dim as long n = 0
		dim as boolean ok = true
		for each v in q
			if( v <> n ) then ok = false
			n += 1
		next
		assert_( ok )
		assert_( n = 10000 )

		'' Clear frees the whole chain and leaves it usable
		q.Clear( )
		assert_( q.Count( ) = 0 )
		assert_( q.IsEmpty( ) )
		q.PushBack( 1 )
		assert_( q.Count( ) = 1 )
	end scope

	'' ==================================================== FOR EACH

	scope
		dim q as LinkedList( of long )
		for i as long = 1 to 5
			q.PushBack( i )
		next

		'' inferred, copy binding
		dim as long total = 0
		for each v in q
			v *= 100
			total += v
		next
		assert_( total = 1500 )
		assert_( q.Front( ) = 1 )       '' untouched

		'' explicit element type
		total = 0
		for each v as long in q
			total += v
		next
		assert_( total = 15 )

		'' byref binding writes through into the nodes
		for each byref v in q
			v *= 2
		next
		assert_( q.Front( ) = 2 )
		assert_( q.Back( ) = 10 )

		'' exit for and continue for
		total = 0
		for each v in q
			if( v = 4 ) then continue for
			if( v > 8 ) then exit for
			total += v
		next
		assert_( total = 2 + 6 + 8 )

		'' nested iteration over the same list
		dim as long pairs = 0
		for each x in q
			for each y in q
				pairs += 1
			next
		next
		assert_( pairs = 25 )
	end scope

	'' ==================================================== copy and assignment
	''
	'' The section this container exists to get right: a shallow copy would give
	'' two lists sharing one chain, and the second destructor would double-free.

	scope
		dim a as LinkedList( of long )
		for i as long = 1 to 5
			a.PushBack( i )
		next

		'' copy construction
		dim b as LinkedList( of long ) = a
		assert_( b.Count( ) = 5 )
		assert_( b.Front( ) = 1 )
		assert_( b.Back( ) = 5 )

		'' writing the copy must not touch the original
		b.PushBack( 6 )
		b.Front( ) = 99
		assert_( a.Count( ) = 5 )
		assert_( a.Front( ) = 1 )

		'' ...and writing the original must not touch the copy
		a.PushFront( 0 )
		assert_( b.Count( ) = 6 )
		assert_( b.Front( ) = 99 )

		'' assignment: old contents go, no sharing afterwards
		dim c as LinkedList( of long )
		c.PushBack( 77 )
		c = a
		assert_( c.Count( ) = 6 )
		assert_( c.Front( ) = 0 )
		c.PushBack( 1000 )
		assert_( a.Count( ) = 6 )
		a.PushBack( 2000 )
		assert_( c.Count( ) = 7 )

		'' self-assignment must not free the chain and then walk it
		c = c
		assert_( c.Count( ) = 7 )
		assert_( c.Front( ) = 0 )

		'' assigning an empty list over a full one empties it
		dim d as LinkedList( of long )
		c = d
		assert_( c.Count( ) = 0 )
		assert_( c.IsEmpty( ) )
		assert_( a.Count( ) = 7 )

		'' and the emptied list still works
		c.PushBack( 5 )
		assert_( c.Count( ) = 1 )

		'' copying an empty list
		dim e as LinkedList( of long ) = d
		assert_( e.Count( ) = 0 )
		e.PushBack( 1 )
		assert_( d.Count( ) = 0 )
	end scope

	'' ==================================================== element types

	scope
		'' strings, which carry their own storage
		dim qs as LinkedList( of string )
		qs.PushBack( "ada" )
		qs.PushFront( "grace" )
		assert_( qs.Front( ) = "grace" )
		assert_( qs.Back( ) = "ada" )
		dim qs2 as LinkedList( of string ) = qs
		qs2.PopFront( )
		assert_( qs.Count( ) = 2 )
		assert_( qs2.Count( ) = 1 )

		'' a nested container as the element
		dim qa as LinkedList( of Array( of long ) )
		dim inner as Array( of long )
		inner.Push( 1 ) : inner.Push( 2 )
		qa.PushBack( inner )
		inner.Push( 3 )
		qa.PushBack( inner )

		assert_( qa.Count( ) = 2 )
		assert_( qa.Front( ).Count( ) = 2 )     '' copied in, not aliased
		assert_( qa.Back( ).Count( ) = 3 )

		dim qa2 as LinkedList( of Array( of long ) ) = qa
		qa2.PopFront( )
		assert_( qa.Count( ) = 2 )
		assert_( qa2.Count( ) = 1 )
	end scope

	'' ==================================================== destructor balance
	''
	'' Every node holds a T, and every node is deleted by hand.  A leak or a
	'' double-free shows up here as an imbalance.

	liveCounted = 0

	scope
		dim q as LinkedList( of Counted )

		for i as long = 0 to 99
			dim as Counted c = Counted( i )
			q.PushBack( c )
		next
		assert_( q.Count( ) = 100 )

		dim as Counted got = q.PopFront( )
		assert_( got.v = 0 )
		got = q.PopBack( )
		assert_( got.v = 99 )
		assert_( q.Count( ) = 98 )

		dim q2 as LinkedList( of Counted ) = q   '' deep copy: 98 more nodes
		assert_( q2.Count( ) = 98 )

		q2.Clear( )
		assert_( q2.Count( ) = 0 )

		dim q3 as LinkedList( of Counted )
		q3 = q                                   '' assignment: 98 more again
		assert_( q3.Count( ) = 98 )
	end scope

	assert_( liveCounted = 0 )
