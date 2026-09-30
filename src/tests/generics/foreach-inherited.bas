' TEST_MODE : COMPILE_AND_RUN_OK

'' FOR EACH finds the iterator protocol in base classes.
''
'' Only the collection's own members were searched, so a type whose
'' GetIterator came from its base was "not iterable" although calling
'' x.GetIterator( ) directly worked -- with or without generics.  The members
'' are now looked up the way a hand-written call resolves them: the type's
'' own first, then each base in turn.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------------------------ plain types

type It
	as long ptr p
	as long i, n
	declare function IsValid( ) as boolean
	declare function Value( ) byref as long
	declare sub MoveNext( )
end type
function It.IsValid( ) as boolean : return this.i < this.n : end function
function It.Value( ) byref as long : return this.p[ this.i ] : end function
sub It.MoveNext( ) : this.i += 1 : end sub

type Baza extends object
	as long v( 0 to 2 ) = { 1, 2, 3 }
	declare function GetIterator( ) as It
end type
function Baza.GetIterator( ) as It
	dim r as It : r.p = @this.v( 0 ) : r.n = 3 : return r
end function

type Derivat extends Baza
end type

'' two levels down
type Nepot extends Derivat
	as long extra = 100
end type

scope
	dim d as Derivat
	dim as long sum = 0
	for each x as long in d
		sum += x
	next
	assert_( sum = 6 )

	dim n as Nepot
	sum = 0
	for each x as long in n
		sum += x
	next
	assert_( sum = 6 )

	'' BYREF binding through the inherited Value( )
	for each byref x as long in d
		x *= 10
	next
	assert_( d.v( 2 ) = 30 )
end scope

'' ---------------------------------------- the iterator's members inherited

type ItBase extends object
	as long i, n
	declare function IsValid( ) as boolean
	declare sub MoveNext( )
end type
function ItBase.IsValid( ) as boolean : return this.i < this.n : end function
sub ItBase.MoveNext( ) : this.i += 1 : end sub

type Squares extends ItBase
	declare function Value( ) as long
end type
function Squares.Value( ) as long : return this.i * this.i : end function

type Range
	as long n
	declare function GetIterator( ) as Squares
end type
function Range.GetIterator( ) as Squares
	dim s as Squares : s.n = this.n : return s
end function

scope
	dim r as Range : r.n = 4
	dim as long sum = 0
	for each x as long in r
		sum += x
	next
	assert_( sum = 0 + 1 + 4 + 9 )
end scope

'' ------------------------------------------------ own member wins over base

type Shadow extends Baza
	declare function GetIterator( ) as It
end type
function Shadow.GetIterator( ) as It
	dim r as It : r.p = @this.v( 1 ) : r.n = 2 : return r
end function

scope
	dim s as Shadow
	dim as long sum = 0
	for each x as long in s
		sum += x
	next
	assert_( sum = 2 + 3 )
end scope

'' -------------------------------------------------------- a generic base

type GBase( of T ) extends object
	as T v( 0 to 2 )
	declare function GetIterator( ) as GIt( of T )
end type

type GIt( of T )
	as T ptr p
	as long i
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type
function GIt( of T ).IsValid( ) as boolean : return this.i < 3 : end function
function GIt( of T ).Value( ) byref as T : return this.p[ this.i ] : end function
sub GIt( of T ).MoveNext( ) : this.i += 1 : end sub

function GBase( of T ).GetIterator( ) as GIt( of T )
	dim r as GIt( of T ) : r.p = @this.v( 0 ) : return r
end function

type GDerived( of T ) extends GBase( of T )
end type

scope
	dim g as GDerived( of double )
	g.v( 0 ) = 0.5 : g.v( 1 ) = 1.5 : g.v( 2 ) = 2
	dim as double sum = 0
	for each x as double in g
		sum += x
	next
	assert_( sum = 4 )

	dim gs as GDerived( of string )
	gs.v( 0 ) = "a" : gs.v( 1 ) = "b" : gs.v( 2 ) = "c"
	dim as string all
	for each x as string in gs
		all &= x
	next
	assert_( all = "abc" )
end scope

'' ------------------------------------------------ a virtual GetIterator

type VBase extends object
	as long v( 0 to 2 ) = { 1, 2, 3 }
	declare virtual function GetIterator( ) as It
end type
function VBase.GetIterator( ) as It
	dim r as It : r.p = @this.v( 0 ) : r.n = 3 : return r
end function

type VFirstOnly extends VBase
	declare function GetIterator( ) as It override
end type
function VFirstOnly.GetIterator( ) as It
	dim r as It : r.p = @this.v( 0 ) : r.n = 1 : return r
end function

type VPlain extends VBase
end type

function SumAll( byref b as VBase ) as long
	dim as long sum = 0
	for each x as long in b
		sum += x
	next
	return sum
end function

scope
	dim f as VFirstOnly
	dim p as VPlain
	assert_( SumAll( f ) = 1 )      '' dispatched to the override
	assert_( SumAll( p ) = 6 )      '' inherited, through a base reference
	dim as long sum = 0
	for each x as long in p         '' inherited, on the derived type itself
		sum += x
	next
	assert_( sum = 6 )
end scope
