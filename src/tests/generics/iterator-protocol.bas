' TEST_MODE : COMPILE_AND_RUN_OK

'' RFC-0002 conformance suite -- the iterator protocol.
''
''     a type is ITERABLE  if it has  GetIterator() as I
''     a type is ITERATOR  if it has  IsValid() as boolean
''                                    Value() [byref] as E
''                                    MoveNext()
''
'' The contract is STRUCTURAL: a type conforms because name lookup finds the
'' members, not because it inherits anything.  So there is nothing for the
'' compiler to enforce yet -- RFC-0003's 'for each' is what consumes this -- and
'' what this file asserts is that every shape the RFC specifies is EXPRESSIBLE
'' and behaves as the RFC says.
''
'' That is not a formality.  Writing it out found one real compiler bug: a
'' generic collection could not return a generic iterator at all, because
'' cProcHeader kept the pending procedure name in a function-static buffer and
'' re-enters itself when a return type names a generic.  See the 'generic
'' collection' section below.
''
'' §4 (built-in arrays and strings being intrinsically iterable) and §7 (the
'' near-miss diagnostics) are deliberately NOT here: both are things 'for each'
'' does, and neither is observable until RFC-0003 exists.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ============================================================ §Guide, verbatim
''
'' The linked-list example from the RFC's guide-level section, spelled exactly
'' as written there.  If this stops compiling, the RFC's own example is wrong.

type IntNode
	as long value
	as IntNode ptr nxt
end type

type IntListIterator
	as IntNode ptr node
	declare function IsValid( ) as boolean
	declare function Value( ) byref as long
	declare sub MoveNext( )
end type

function IntListIterator.IsValid( ) as boolean
	return this.node <> 0
end function

function IntListIterator.Value( ) byref as long
	return this.node->value
end function

sub IntListIterator.MoveNext( )
	this.node = this.node->nxt
end sub

type IntList
	as IntNode ptr head
	declare function GetIterator( ) as IntListIterator
end type

function IntList.GetIterator( ) as IntListIterator
	dim it as IntListIterator
	it.node = this.head
	return it
end function

'' ================================================================ §5.3, generic
''
'' One iterator written once, over any element type.
''
'' This is the shape RFC-0004's containers all return, and the one that did not
'' compile before Phase 10:
''
''     declare function GetIterator( ) as ArrayIterator( of T )
''     error 158: Declaration outside the original namespace or class
''
'' Parsing that return type instantiates ArrayIterator right there, in the middle
'' of cProcHeader, and the instantiated type's own member prototypes come back
'' through cProcHeader -- overwriting the static buffer holding 'GetIterator'.
'' The collection ended up with a member named after the iterator's LAST member
'' and no GetIterator at all, so the out-of-line body had no prototype to match.

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

'' ================================================= §1, Value() BY VALUE is legal
''
'' 'Value() [byref] as E' -- the byref is optional.  A by-value Value yields a
'' copy, and RFC-0003 will reject 'for each byref' against it.

type CopyIterator
	as long idx, count
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

function CopyIterator.IsValid( ) as boolean
	return this.idx < this.count
end function

function CopyIterator.Value( ) as long
	return this.idx * this.idx
end function

sub CopyIterator.MoveNext( )
	this.idx += 1
end sub

type Squares
	as long count
	declare function GetIterator( ) as CopyIterator
end type

function Squares.GetIterator( ) as CopyIterator
	dim it as CopyIterator
	it.idx = 0
	it.count = this.count
	return it
end function

'' =========================================================== §1, const iterable
''
'' 'GetIterator may be const' -- yes, and a const GetIterator serves a const and
'' a non-const collection alike.
''
'' The rest of that sentence -- 'if both a const and a non-const overload exist,
'' the usual overload rules select one against the constness of the collection
'' expression' -- is NOT SATISFIABLE in FreeBASIC today, and this is where the
'' conformance suite earns its keep.  Constness alone does not distinguish an
'' overload:
''
''     declare function f( ) as long
''     declare const function f( ) as long
''     error 4: Duplicated definition
''
'' Confirmed against a plain non-generic control before it was believed, so it
'' is a language limitation and not something generics introduced.  Nothing
'' depends on the overload pair: one const GetIterator covers both cases, which
'' is what a container wants anyway.

type Pair2
	as long a, b
end type

type PairIter
	as Pair2 ptr p
	as long idx
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

function PairIter.IsValid( ) as boolean
	return this.idx < 2
end function

function PairIter.Value( ) as long
	if this.idx = 0 then return this.p->a
	return this.p->b
end function

sub PairIter.MoveNext( )
	this.idx += 1
end sub

type ConstBox
	as Pair2 v
	declare const function GetIterator( ) as PairIter
end type

const function ConstBox.GetIterator( ) as PairIter
	dim it as PairIter
	it.p = cptr( Pair2 ptr, @this.v )
	it.idx = 0
	return it
end function

'' ============================================================ §6, iterators are
''                                                              ordinary values
''
'' 'If it holds resources, it declares a destructor and the destructor runs when
'' the loop ends.'  The protocol adds no lifetime rule -- it relies on the one
'' FreeBASIC already has.

dim shared as long liveiters, totaliters

type OwningIterator
	as long idx, count
	declare constructor( )
	declare constructor( byref rhs as OwningIterator )
	declare destructor( )
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

constructor OwningIterator( )
	liveiters += 1
	totaliters += 1
end constructor

constructor OwningIterator( byref rhs as OwningIterator )
	this.idx = rhs.idx
	this.count = rhs.count
	liveiters += 1
	totaliters += 1
end constructor

destructor OwningIterator( )
	liveiters -= 1
end destructor

function OwningIterator.IsValid( ) as boolean
	return this.idx < this.count
end function

function OwningIterator.Value( ) as long
	return this.idx
end function

sub OwningIterator.MoveNext( )
	this.idx += 1
end sub

type Owning
	as long count
	declare function GetIterator( ) as OwningIterator
end type

function Owning.GetIterator( ) as OwningIterator
	dim it as OwningIterator
	it.count = this.count
	return it
end function

'' ============================== §5, coexistence with the operator for protocol
''
'' 'The existing operator for / next / step triple is untouched.  A type may
'' implement both.  They do not interfere.'
''
'' Rng below is BOTH: it is a range usable with 'for i as Rng = a to b', and an
'' iterator usable through the RFC-0002 members.  Nothing about having one set
'' of members changes the meaning of the other.

type Rng
	as long cur
	declare constructor( )
	declare constructor( byval v as long )
	declare operator let( byref rhs as Rng )
	declare operator for( )
	declare operator next( byref cond as Rng ) as integer
	declare operator step( )

	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
	declare function GetIterator( ) as Rng
end type

constructor Rng( )
	this.cur = 0
end constructor

constructor Rng( byval v as long )
	this.cur = v
end constructor

operator Rng.let( byref rhs as Rng )
	this.cur = rhs.cur
end operator

operator Rng.for( )
end operator

operator Rng.next( byref cond as Rng ) as integer
	return this.cur <= cond.cur
end operator

operator Rng.step( )
	this.cur += 1
end operator

function Rng.IsValid( ) as boolean
	return this.cur <= 5
end function

function Rng.Value( ) as long
	return this.cur
end function

sub Rng.MoveNext( )
	this.cur += 1
end sub

'' §Unresolved-2: a collection may BE its own iterator.  Proposed in the RFC as
'' permitted and documented as a footgun; pinned here as permitted.
function Rng.GetIterator( ) as Rng
	return *@this
end function

	'' ---------------------------------------------------------- guide example

	dim as IntNode n3 = ( 3, 0 )
	dim as IntNode n2 = ( 2, @n3 )
	dim as IntNode n1 = ( 1, @n2 )
	dim as IntList lst
	lst.head = @n1

	dim sum as long = 0
	dim it as IntListIterator = lst.GetIterator( )
	while it.IsValid( )
		sum += it.Value( )
		it.MoveNext( )
	wend
	assert_( sum = 6 )

	'' after the last element, IsValid is false -- and stays false
	assert_( it.IsValid( ) = false )
	assert_( it.IsValid( ) = false )

	'' §2: byref Value mutates the collection in place
	it = lst.GetIterator( )
	while it.IsValid( )
		it.Value( ) *= 10
		it.MoveNext( )
	wend
	assert_( n1.value = 10 )
	assert_( n2.value = 20 )
	assert_( n3.value = 30 )

	'' §2: a fresh iterator refers to the FIRST element -- there is no
	'' "before the first" state, so Value is legal without a MoveNext first
	dim it2 as IntListIterator = lst.GetIterator( )
	assert_( it2.IsValid( ) )
	assert_( it2.Value( ) = 10 )

	'' §2: Value may be called more than once for the same element
	assert_( it2.Value( ) = 10 )

	'' two independent iterators do not interfere
	dim it3 as IntListIterator = lst.GetIterator( )
	it3.MoveNext( )
	assert_( it3.Value( ) = 20 )
	assert_( it2.Value( ) = 10 )

	'' §2: an empty collection has IsValid false immediately
	dim as IntList empty_
	empty_.head = 0
	dim ite as IntListIterator = empty_.GetIterator( )
	assert_( ite.IsValid( ) = false )

	'' ------------------------------------------------------ generic collection

	dim as Buf( of long ) bl
	bl.push( 5 ) : bl.push( 6 ) : bl.push( 7 )

	dim itl as ArrayIterator( of long ) = bl.GetIterator( )
	dim lsum as long = 0
	while itl.IsValid( )
		lsum += itl.Value( )
		itl.MoveNext( )
	wend
	assert_( lsum = 18 )

	'' byref Value through the generic iterator
	itl = bl.GetIterator( )
	while itl.IsValid( )
		itl.Value( ) += 100
		itl.MoveNext( )
	wend
	assert_( bl.e( 0 ) = 105 )
	assert_( bl.e( 1 ) = 106 )
	assert_( bl.e( 2 ) = 107 )

	'' a second element type: same iterator, different instantiation
	dim as Buf( of string ) bs
	dim as string s1 = "ab", s2 = "cd"
	bs.push( s1 ) : bs.push( s2 )

	dim its as ArrayIterator( of string ) = bs.GetIterator( )
	dim cat as string = ""
	while its.IsValid( )
		cat += its.Value( )
		its.MoveNext( )
	wend
	assert_( cat = "abcd" )

	'' §1: E may itself be a UDT
	dim as Buf( of Pair2 ) bp
	dim as Pair2 pv
	pv.a = 1 : pv.b = 2
	bp.push( pv )
	pv.a = 3 : pv.b = 4
	bp.push( pv )

	dim itp as ArrayIterator( of Pair2 ) = bp.GetIterator( )
	dim psum as long = 0
	while itp.IsValid( )
		psum += itp.Value( ).a + itp.Value( ).b
		itp.MoveNext( )
	wend
	assert_( psum = 10 )

	'' §1: E may itself be a generic instantiation
	dim as Buf( of Buf( of long ) ) bb
	bb.push( bl )
	dim itb as ArrayIterator( of Buf( of long ) ) = bb.GetIterator( )
	assert_( itb.IsValid( ) )
	assert_( itb.Value( ).e( 0 ) = 105 )

	'' an empty generic collection
	dim as Buf( of long ) bempty
	dim itz as ArrayIterator( of long ) = bempty.GetIterator( )
	assert_( itz.IsValid( ) = false )

	'' ------------------------------------------------------- Value() by value

	dim as Squares sq
	sq.count = 4
	dim itc as CopyIterator = sq.GetIterator( )
	dim qsum as long = 0
	while itc.IsValid( )
		qsum += itc.Value( )
		itc.MoveNext( )
	wend
	assert_( qsum = 0 + 1 + 4 + 9 )

	'' ------------------------------------------------------------ const iterable

	dim as ConstBox cb
	cb.v.a = 11 : cb.v.b = 22

	'' the same const GetIterator, reached from a NON-const collection
	dim itk as PairIter = cb.GetIterator( )
	assert_( itk.Value( ) = 11 )
	itk.MoveNext( )
	assert_( itk.Value( ) = 22 )

	scope
		'' and from a const one -- which a non-const GetIterator could not serve
		dim as const ConstBox ccb = cb
		dim itcc as PairIter = ccb.GetIterator( )
		assert_( itcc.Value( ) = 11 )
		itcc.MoveNext( )
		assert_( itcc.Value( ) = 22 )
	end scope

	'' ------------------------------------------------ iterators are values (§6)

	liveiters = 0 : totaliters = 0

	scope
		dim as Owning ow
		ow.count = 3

		dim ito as OwningIterator = ow.GetIterator( )
		dim osum as long = 0
		while ito.IsValid( )
			osum += ito.Value( )
			ito.MoveNext( )
		wend
		assert_( osum = 3 )
		assert_( liveiters > 0 )
	end scope

	'' every iterator constructed was destroyed -- a leak shows up as an
	'' imbalance, which is the memcheck written as an assertion
	assert_( liveiters = 0 )
	assert_( totaliters > 0 )

	'' ----------------------------------------- both protocols on the same type

	dim rtotal as long = 0
	for i as Rng = Rng( 1 ) to Rng( 5 )
		rtotal += i.cur
	next
	assert_( rtotal = 15 )              '' operator for/next/step, untouched

	dim itr as Rng = Rng( 1 ).GetIterator( )
	dim rsum as long = 0
	while itr.IsValid( )
		rsum += itr.Value( )
		itr.MoveNext( )
	wend
	assert_( rsum = 15 )                '' RFC-0002 members, same type

	'' and the for loop still works afterwards
	rtotal = 0
	for i as Rng = Rng( 2 ) to Rng( 4 )
		rtotal += i.cur
	next
	assert_( rtotal = 9 )
