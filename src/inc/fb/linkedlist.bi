'' fb/linkedlist.bi -- FB.LinkedList( of T ), a doubly-linked list
''
'' RFC-0004 §6 (there called List).  Included because Array cannot give O(1)
'' insertion at the front, and because a LinkedList iterator stays valid across
'' insertions elsewhere in the list.
''
''     dim q as FB.LinkedList( of string )
''     q.PushBack( "b" )
''     q.PushFront( "a" )
''     print q.PopFront( )                 '' "a"
''
'' It is the least important of the four containers and is here mainly so that
'' the answer to "what if I need a queue" is not "write your own".  Prefer Array
'' unless front insertion or iterator stability is what you actually need.
''
'' OWNERSHIP.  Unlike Array, Map and Set -- whose storage is a dynamic array
'' field, so the language deep-copies and destroys it for free -- this holds RAW
'' NODE POINTERS.  The default copy would duplicate the head and tail pointers
'' and give two lists sharing one chain, which then double-frees.  So the
'' destructor, the copy constructor and 'operator let' are all written out, and
'' they are the reason this file is longer than it looks.

#pragma once

namespace FB

type LinkedNode( of T )
	as T value
	as LinkedNode( of T ) ptr nxt
	as LinkedNode( of T ) ptr prv
end type

type LinkedListIterator( of T )
	as any ptr node
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type

type LinkedList( of T )
	as LinkedNode( of T ) ptr head
	as LinkedNode( of T ) ptr tail
	as long num

	declare constructor( )
	declare constructor( byref rhs as LinkedList( of T ) )
	declare destructor( )
	declare operator let( byref rhs as LinkedList( of T ) )

	declare function Count( ) as long
	declare function IsEmpty( ) as boolean

	declare sub PushFront( byref v as T )
	declare sub PushBack( byref v as T )
	declare function PopFront( ) as T
	declare function PopBack( ) as T
	declare function Front( ) byref as T
	declare function Back( ) byref as T

	declare sub Clear( )
	declare sub CopyFrom( byref rhs as LinkedList( of T ) )

	declare function GetIterator( ) as LinkedListIterator( of T )
end type

constructor LinkedList( of T )( )
	this.head = 0
	this.tail = 0
	this.num = 0
end constructor

'' Deep copy.  Without this the compiler-supplied copy would share the chain.
constructor LinkedList( of T )( byref rhs as LinkedList( of T ) )
	this.head = 0
	this.tail = 0
	this.num = 0
	this.CopyFrom( rhs )
end constructor

destructor LinkedList( of T )( )
	this.Clear( )
end destructor

operator LinkedList( of T ).let( byref rhs as LinkedList( of T ) )
	'' Self-assignment would otherwise free the chain and then walk it.
	if( @rhs = @this ) then
		exit operator
	end if
	this.Clear( )
	this.CopyFrom( rhs )
end operator

sub LinkedList( of T ).CopyFrom( byref rhs as LinkedList( of T ) )
	dim as LinkedNode( of T ) ptr p = rhs.head
	while( p )
		this.PushBack( p->value )
		p = p->nxt
	wend
end sub

function LinkedList( of T ).Count( ) as long
	return this.num
end function

function LinkedList( of T ).IsEmpty( ) as boolean
	return this.num = 0
end function

sub LinkedList( of T ).PushFront( byref v as T )
	'' Copy first: v may refer INTO this list -- 'q.PushFront( q.Back( ) )' is
	'' legal -- and the node is linked in before the value is stored.
	dim as T vv = v

	dim as LinkedNode( of T ) ptr n = new LinkedNode( of T )
	n->value = vv
	n->prv = 0
	n->nxt = this.head

	if( this.head ) then
		this.head->prv = n
	else
		this.tail = n
	end if

	this.head = n
	this.num += 1
end sub

sub LinkedList( of T ).PushBack( byref v as T )
	dim as T vv = v

	dim as LinkedNode( of T ) ptr n = new LinkedNode( of T )
	n->value = vv
	n->nxt = 0
	n->prv = this.tail

	if( this.tail ) then
		this.tail->nxt = n
	else
		this.head = n
	end if

	this.tail = n
	this.num += 1
end sub

'' Removing from an empty list returns a default-constructed T.  There is no
'' error channel here and no exception to throw; check IsEmpty( ) first if the
'' difference matters.
function LinkedList( of T ).PopFront( ) as T
	dim as T r

	if( this.head = 0 ) then
		return r
	end if

	dim as LinkedNode( of T ) ptr n = this.head
	r = n->value

	this.head = n->nxt
	if( this.head ) then
		this.head->prv = 0
	else
		this.tail = 0
	end if

	delete n
	this.num -= 1

	return r
end function

function LinkedList( of T ).PopBack( ) as T
	dim as T r

	if( this.tail = 0 ) then
		return r
	end if

	dim as LinkedNode( of T ) ptr n = this.tail
	r = n->value

	this.tail = n->prv
	if( this.tail ) then
		this.tail->nxt = 0
	else
		this.head = 0
	end if

	delete n
	this.num -= 1

	return r
end function

'' Front and Back on an empty list return a reference to a shared blank.  A
'' reference has to refer to something, and there is nothing else to refer to.
function LinkedList( of T ).Front( ) byref as T
	static as T blank
	if( this.head = 0 ) then
		return blank
	end if
	return this.head->value
end function

function LinkedList( of T ).Back( ) byref as T
	static as T blank
	if( this.tail = 0 ) then
		return blank
	end if
	return this.tail->value
end function

sub LinkedList( of T ).Clear( )
	dim as LinkedNode( of T ) ptr p = this.head

	while( p )
		dim as LinkedNode( of T ) ptr nxt = p->nxt
		delete p
		p = nxt
	wend

	this.head = 0
	this.tail = 0
	this.num = 0
end sub

function LinkedList( of T ).GetIterator( ) as LinkedListIterator( of T )
	dim it as LinkedListIterator( of T )
	it.node = this.head
	return it
end function

function LinkedListIterator( of T ).IsValid( ) as boolean
	return this.node <> 0
end function

function LinkedListIterator( of T ).Value( ) byref as T
	dim as LinkedNode( of T ) ptr n = cptr( LinkedNode( of T ) ptr, this.node )
	return n->value
end function

sub LinkedListIterator( of T ).MoveNext( )
	dim as LinkedNode( of T ) ptr n = cptr( LinkedNode( of T ) ptr, this.node )
	this.node = n->nxt
end sub

end namespace
