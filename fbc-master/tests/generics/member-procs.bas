' TEST_MODE : COMPILE_AND_RUN_OK

'' Out-of-line member bodies.
''
'' A prototype inside a generic's body comes free -- the whole 'type ... end
'' type' is replayed.  The body is the new part: 'sub Stack( of T ).Push' is
'' captured once and replayed once per instantiation, at a module-level
'' statement boundary rather than where the instantiation was asked for.
''
'' Note on names: a type parameter called K cannot be used as a parameter type
'' in FreeBASIC at all (plain 'type K as long' + 'declare sub f( byval a as K )'
'' is rejected the same way), so these use TK/TV.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ---------------------------------------------------------------- one param

type Box( of T )
	as T v
	declare sub setit( byval x as T )
	declare function getit( ) as T
end type

sub Box( of T ).setit( byval x as T )
	this.v = x
end sub

function Box( of T ).getit( ) as T
	return this.v
end function

'' ------------------------------------------- two params, both orders of use

type Pair( of TK, TV )
	as TK k
	as TV v
	declare sub setboth( byval a as TK, byval b as TV )
	declare function first( ) as TK
	declare function second( ) as TV
end type

'' written BEFORE any instantiation exists
sub Pair( of TK, TV ).setboth( byval a as TK, byval b as TV )
	this.k = a
	this.v = b
end sub

'' ------------------------------------ control flow, locals, sibling calls

type Vec3( of T )
	as T a, b, c
	declare sub fill( byval x as T )
	declare function total( ) as T
	declare function twice( ) as T
end type

sub Vec3( of T ).fill( byval x as T )
	dim as T tmp = x
	for i as integer = 0 to 2
		select case i
		case 0 : this.a = tmp
		case 1 : this.b = tmp
		case else : this.c = tmp
		end select
	next
end sub

function Vec3( of T ).total( ) as T
	dim as T s = this.a + this.b + this.c
	if s > 0 then
		return s
	end if
	return 0
end function

function Vec3( of T ).twice( ) as T
	'' calls a sibling method on the same instantiation
	return this.total( ) * 2
end function

'' -------------------------- a member body that instantiates another generic

type Inner( of T )
	as T v
	declare sub setv( byval x as T )
end type

sub Inner( of T ).setv( byval x as T )
	this.v = x
end sub

type Outer( of T )
	as T v
	declare function make( byval x as T ) as T
end type

function Outer( of T ).make( byval x as T ) as T
	'' Inner( of long ) is first instantiated HERE, inside a replayed body.
	'' Both the instantiation and its own member bodies have to be hoisted to
	'' module level, or a UDT with methods is rejected below module level.
	dim i as Inner( of T )
	i.setv( x )
	return i.v
end function

'' ---------------------------------------------------------------- namespace

namespace ns
	type Wrapped( of T )
		as T v
		declare sub setv( byval x as T )
	end type
	sub Wrapped( of T ).setv( byval x as T )
		this.v = x
	end sub
end namespace

	dim b as Box( of long )
	b.setit( 42 )
	assert_( b.getit( ) = 42 )

	dim bs as Box( of string )
	bs.setit( "hi" )
	assert_( bs.getit( ) = "hi" )

	'' two instantiations of a two-parameter generic
	dim p1 as Pair( of long, double )
	p1.setboth( 7, 2.5 )
	assert_( p1.first( ) = 7 )
	assert_( p1.second( ) = 2.5 )

	dim p2 as Pair( of string, integer )
	p2.setboth( "hi", 9 )
	assert_( p2.first( ) = "hi" )
	assert_( p2.second( ) = 9 )

	dim v as Vec3( of long )
	v.fill( 5 )
	assert_( v.total( ) = 15 )
	assert_( v.twice( ) = 30 )

	dim w as Vec3( of double )
	w.fill( 1.5 )
	assert_( w.total( ) = 4.5 )
	assert_( w.twice( ) = 9.0 )

	dim o as Outer( of long )
	assert_( o.make( 11 ) = 11 )

	dim od as Outer( of double )
	assert_( od.make( 0.5 ) = 0.5 )

	dim wr as ns.Wrapped( of long )
	wr.setv( 4 )
	assert_( wr.v = 4 )

'' Bodies written AFTER both Pair instantiations already exist: they have to
'' retro-queue for each of them, which is the half of the deferred queue that
'' declaration order would otherwise hide.
function Pair( of TK, TV ).first( ) as TK
	return this.k
end function

function Pair( of TK, TV ).second( ) as TV
	return this.v
end function
