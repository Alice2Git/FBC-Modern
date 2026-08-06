' TEST_MODE : COMPILE_AND_RUN_OK

'' RFC-0003 -- FOR EACH.
''
''     for each [byref] x [as E] in <collection>
''        BODY
''     next
''
'' Defined entirely as a desugaring, with two lowerings and no new AST node, IR
'' node, code generator change or runtime call:
''
''   a user collection satisfying RFC-0002
''       dim __it = c.GetIterator( ) : goto test
''     ini:  scope : dim x = __it.Value( ) : BODY : end scope
''     cmp:  __it.MoveNext( )                       '' CONTINUE FOR lands here
''    test:  if __it.IsValid( ) then goto ini
''
''   an array or a var-len STRING
''       an ordinary FOR over a hidden counter from lbound to ubound, with the
''       element bound at the top of the body.  It fills the same compound-stmt
''       entry an ordinary FOR does, so the existing scalar close advances and
''       tests it and the emitted code is what the hand-written index loop
''       emits.
''
'' Both share the FB_TK_FOR stack entry, which is what makes EXIT FOR and
'' CONTINUE FOR work with nothing new.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------- an RFC-0002 collection, generic

type ArrayIterator( of T )
	as T ptr first
	as long idx, count
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type

function ArrayIterator( of T ).IsValid( ) as boolean
	return this.idx < this.count
end function

function ArrayIterator( of T ).Value( ) byref as T
	return this.first[ this.idx ]
end function

sub ArrayIterator( of T ).MoveNext( )
	this.idx += 1
end sub

type Buf( of T )
	as T e( 0 to 7 )
	as long n
	declare function GetIterator( ) as ArrayIterator( of T )
	declare sub push( byref v as T )
end type

sub Buf( of T ).push( byref v as T )
	this.e( this.n ) = v
	this.n += 1
end sub

function Buf( of T ).GetIterator( ) as ArrayIterator( of T )
	dim it as ArrayIterator( of T )
	it.first = @this.e( 0 )
	it.idx = 0
	it.count = this.n
	return it
end function

'' ------------------------------- a non-generic collection, Value() BY VALUE

type SqIter
	as long idx, count
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

function SqIter.IsValid( ) as boolean
	return this.idx < this.count
end function

function SqIter.Value( ) as long
	return this.idx * this.idx
end function

sub SqIter.MoveNext( )
	this.idx += 1
end sub

type Squares
	as long count
	declare function GetIterator( ) as SqIter
end type

function Squares.GetIterator( ) as SqIter
	dim it as SqIter
	it.idx = 0
	it.count = this.count
	return it
end function

'' ------------------------------------------- an iterator that owns something
''
'' RFC-0002 §6: the iterator is an ordinary scoped value, so its destructor runs
'' when the loop ends -- including on EXIT FOR.  The protocol adds no lifetime
'' rule; this is FreeBASIC's existing scope semantics.

dim shared as long liveiters

type OwningIter
	as long idx, count
	declare constructor( )
	declare constructor( byref rhs as OwningIter )
	declare destructor( )
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

constructor OwningIter( )
	liveiters += 1
end constructor

constructor OwningIter( byref rhs as OwningIter )
	this.idx = rhs.idx
	this.count = rhs.count
	liveiters += 1
end constructor

destructor OwningIter( )
	liveiters -= 1
end destructor

function OwningIter.IsValid( ) as boolean
	return this.idx < this.count
end function

function OwningIter.Value( ) as long
	return this.idx
end function

sub OwningIter.MoveNext( )
	this.idx += 1
end sub

type Owning
	as long count
	declare function GetIterator( ) as OwningIter
end type

function Owning.GetIterator( ) as OwningIter
	dim it as OwningIter
	it.count = this.count
	return it
end function

'' ---------------------------------- the collection is evaluated exactly once

dim shared as long gcalls

function makeBuf( ) as Buf( of long )
	gcalls += 1
	dim r as Buf( of long )
	dim as long a = 1, b = 2, c = 3
	r.push( a ) : r.push( b ) : r.push( c )
	return r
end function

	'' ===================================================== backward compatibility
	''
	'' 'each' is NOT a reserved word, and these two are the whole reason the
	'' disambiguation exists.  FreeBASIC's FOR needs a simple scalar counter, so
	'' the token after 'for each' in the OLD form is always AS or '=', and in the
	'' new form never is.

	dim as long compat = 0
	for each as long = 1 to 3
		compat += each
	next
	assert_( compat = 6 )

	dim each as long
	compat = 0
	for each = 4 to 6
		compat += each
	next
	assert_( compat = 15 )

	'' 'in' is contextual too
	dim as long in = 7
	assert_( in = 7 )

	'' ===================================================== arrays

	dim a(0 to 4) as long = { 1, 2, 3, 4, 5 }
	dim t as long = 0

	for each v as long in a
		t += v
	next
	assert_( t = 15 )

	'' the element type is inferred when AS is omitted
	t = 0
	for each v in a
		t += v
	next
	assert_( t = 15 )

	'' a non-zero lbound
	dim b(3 to 5) as long = { 7, 8, 9 }
	t = 0
	for each v in b
		t += v
	next
	assert_( t = 24 )

	'' a dynamic array -- a different base convention entirely: the descriptor's
	'' data field is pre-biased, where a fixed array's is not
	redim d(2 to 4) as long
	d(2) = 10 : d(3) = 20 : d(4) = 30
	t = 0
	for each v in d
		t += v
	next
	assert_( t = 60 )

	'' an unallocated dynamic array iterates zero times
	redim z(any) as long
	t = 0
	for each v in z
		t += 1
	next
	assert_( t = 0 )

	'' byref binding modifies the array
	for each byref v as long in a
		v *= 10
	next
	assert_( a(0) = 10 )
	assert_( a(4) = 50 )

	for each byref v in d
		v += 1
	next
	assert_( d(2) = 11 )
	assert_( d(4) = 31 )

	'' AS with a different type converts per element, exactly as 'dim' does
	dim sum as double = 0
	for each v as double in b
		sum += v / 2
	next
	assert_( sum = 12 )

	'' a UDT element type
	dim strs(0 to 1) as string = { "ab", "cd" }
	dim cat as string = ""
	for each s in strs
		cat += s
	next
	assert_( cat = "abcd" )

	'' ===================================================== var-len string

	dim as string txt = "abc"
	t = 0
	for each c in txt
		t += c
	next
	assert_( t = asc( "a" ) + asc( "b" ) + asc( "c" ) )

	'' an empty string iterates zero times
	dim as string empty_ = ""
	t = 0
	for each c in empty_
		t += 1
	next
	assert_( t = 0 )

	'' ===================================================== user collections

	dim as Buf( of long ) bl
	bl.push( 5 ) : bl.push( 6 ) : bl.push( 7 )

	t = 0
	for each v as long in bl
		t += v
	next
	assert_( t = 18 )

	'' inferred from the iterator's Value( )
	t = 0
	for each v in bl
		t += v
	next
	assert_( t = 18 )

	'' byref, because Value( ) returns byref
	for each byref v as long in bl
		v += 100
	next
	assert_( bl.e(0) = 105 )
	assert_( bl.e(1) = 106 )
	assert_( bl.e(2) = 107 )

	'' an empty collection
	dim as Buf( of long ) bempty
	t = 0
	for each v in bempty
		t += 1
	next
	assert_( t = 0 )

	'' a second instantiation of the same generic
	dim as Buf( of string ) bs
	dim as string s1 = "ab", s2 = "cd"
	bs.push( s1 ) : bs.push( s2 )
	cat = ""
	for each v in bs
		cat += v
	next
	assert_( cat = "abcd" )

	'' a non-generic collection whose Value( ) returns BY VALUE
	dim as Squares sq
	sq.count = 4
	t = 0
	for each v in sq
		t += v
	next
	assert_( t = 0 + 1 + 4 + 9 )

	'' ===================================================== control flow

	t = 0
	for each v in bl
		if v = 106 then continue for
		if v > 106 then exit for
		t += v
	next
	assert_( t = 105 )                  '' CONTINUE FOR must still advance

	'' the same over an array
	t = 0
	for each v in a
		if v = 20 then continue for
		if v > 30 then exit for
		t += v
	next
	assert_( t = 40 )                   '' 10 + 30

	'' nesting, with itself
	dim as Buf( of long ) b2
	dim as long one = 1, two = 2
	b2.push( one ) : b2.push( two )
	t = 0
	for each x in b2
		for each y in b2
			t += x * y
		next
	next
	assert_( t = 9 )

	'' nesting with an ordinary FOR, and EXIT FOR binding to the nearest loop
	t = 0
	for i as long = 1 to 2
		for each v in b2
			if v = 2 then exit for
			t += v * i
		next
	next
	assert_( t = 3 )

	'' and inside a WHILE
	t = 0
	dim as long guard = 0
	while guard < 2
		for each v in b2
			t += v
		next
		guard += 1
	wend
	assert_( t = 6 )

	'' ===================================================== iterator lifetime

	liveiters = 0

	scope
		dim as Owning ow
		ow.count = 5

		t = 0
		for each v in ow
			t += v
		next
		assert_( t = 10 )

		'' EXIT FOR must still destroy the iterator
		for each v in ow
			exit for
		next
	end scope

	assert_( liveiters = 0 )

	'' ================================= the collection is evaluated exactly once

	gcalls = 0
	t = 0
	for each v in makeBuf( )
		t += v
	next
	assert_( t = 6 )
	assert_( gcalls = 1 )

	'' ===================================================== scope of the variable

	'' the loop variable is scoped to the body, so this outer 'v' is untouched
	dim as long v = 99
	for each v in b2
	next
	assert_( v = 99 )
