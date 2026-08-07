' TEST_MODE : COMPILE_AND_RUN_OK

'' Inheritance, VIRTUAL, ABSTRACT and RTTI across generics.
''
'' Three directions, all of them working:
''
''   generic EXTENDS concrete          type Sq( of T ) extends Shape
''   concrete EXTENDS instantiation    type IntBox extends Box( of integer )
''   generic EXTENDS generic           type Der( of T ) extends Root( of T )
''
'' The last is the one that exercised everything: it instantiates the base while
'' replaying the derived's own header, which is a position ordinary FreeBASIC
'' cannot reach -- a base has to be declared before it can be extended.
''
'' The RTTI assertions are the point of the file. oop_istypeof compares MANGLED
'' NAME STRINGS at run time, so two instantiations that collide on a name would
'' report 'is' true for each other. Every negative below is as load-bearing as
'' the positive beside it.
''
'' Note 'x is T' requires a genuine DOWNCAST -- 'dv is D' where dv is already a D
'' is 'error 298: Types have no hierarchical relation' in plain FreeBASIC too.
'' Everything here therefore asks through a base pointer.
''
'' Names: not Base (reserved) and not a name that collides case-insensitively
'' with a variable -- both have produced phantom compiler bugs in this project.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' -------------------------------------------- generic extends a concrete type

type Shape extends object
	declare virtual function nm( ) as string
	declare abstract function area( ) as double
end type

function Shape.nm( ) as string
	return "Shape"
end function

type Sq( of T ) extends Shape
	as T s
	declare function nm( ) as string
	declare function area( ) as double
end type

function Sq( of T ).nm( ) as string
	return "Sq"
end function

function Sq( of T ).area( ) as double
	return this.s * this.s
end function

'' ------------------------------------- concrete extends an instantiated generic

type Box( of T ) extends object
	as T v
	declare virtual function nm( ) as string
end type

function Box( of T ).nm( ) as string
	return "Box"
end function

type IntBox extends Box( of integer )
	declare function nm( ) as string
end type

function IntBox.nm( ) as string
	return "IntBox"
end function

'' --------------------------------------------------- generic extends generic

type Root( of T ) extends object
	as T v
	declare virtual function nm( ) as string
	declare abstract function tag( ) as string
end type

function Root( of T ).nm( ) as string
	return "Root"
end function

type Der( of T ) extends Root( of T )
	as T w
	declare function nm( ) as string
	declare function tag( ) as string
end type

function Der( of T ).nm( ) as string
	return "Der"
end function

function Der( of T ).tag( ) as string
	return "tag"
end function

'' ------------------ a base instantiated with a FIXED argument, not the derived's

type Pinned( of T ) extends Root( of integer )
	as T w
	declare function nm( ) as string
	declare function tag( ) as string
end type

function Pinned( of T ).nm( ) as string
	return "Pinned"
end function

function Pinned( of T ).tag( ) as string
	return "pinned"
end function

'' ------------------------------------------------------ three levels of generic
''
'' Names: not Mid or Fix -- both are FreeBASIC quirk keywords and produce
'' 'Expected identifier', which reads exactly like a compiler bug.

'' 'nm' is re-declared VIRTUAL here, not just overridden.  That is plain
'' FreeBASIC semantics, checked against a non-generic control before it was
'' believed: an override that is not itself virtual cannot be overridden AGAIN
'' further down, and Leaf.nm silently never reaches the vtable.
type Middle( of T ) extends Root( of T )
	declare virtual function nm( ) as string
	declare function tag( ) as string
end type

function Middle( of T ).nm( ) as string
	return "Middle"
end function

function Middle( of T ).tag( ) as string
	return "middle"
end function

type Leaf( of T ) extends Middle( of T )
	declare function nm( ) as string
end type

function Leaf( of T ).nm( ) as string
	return "Leaf"
end function

'' ------------------------------- an EXTENDS reached through a '_' continuation

type Cont( of T ) _
	extends Shape
	as T c
	declare function nm( ) as string
	declare function area( ) as double
end type

function Cont( of T ).nm( ) as string
	return "Cont"
end function

function Cont( of T ).area( ) as double
	return 1
end function

'' --------------------------------------------------------- a generic UNION
''
'' The replay used to be hardcoded to 'type ... end type', so every generic
'' union was silently instantiated as a STRUCT: fields that must overlap did
'' not, and sizeof came out double.  Wrong code, and no diagnostic --
'' capture-boundary.bas declares a generic union but never instantiates one.

union Pun( of T )
	as T a
	as integer b
end union

union PlainPun
	as double a
	as integer b
end union

	'' ------------------------------------------- generic derived, concrete base

	dim as Sq( of integer ) si
	dim as Sq( of double ) sd
	si.s = 4
	sd.s = 0.5

	assert_( si.area( ) = 16 )
	assert_( sd.area( ) = 0.25 )

	dim as Shape ptr p = @si
	assert_( p->nm( ) = "Sq" )          '' virtual, through the concrete base
	assert_( p->area( ) = 16 )          '' abstract, implemented per instantiation

	assert_( (*p is Sq( of integer )) <> 0 )
	assert_( (*p is Sq( of double )) = 0 )

	p = @sd
	assert_( p->area( ) = 0.25 )
	assert_( (*p is Sq( of integer )) = 0 )
	assert_( (*p is Sq( of double )) <> 0 )

	'' ------------------------------------------- concrete derived, generic base

	dim as IntBox ib
	ib.v = 9

	dim as Box( of integer ) ptr q = @ib
	assert_( q->nm( ) = "IntBox" )
	assert_( q->v = 9 )
	assert_( (*q is IntBox) <> 0 )

	'' a Box( of integer ) that is NOT an IntBox
	dim as Box( of integer ) plainbox
	q = @plainbox
	assert_( q->nm( ) = "Box" )
	assert_( (*q is IntBox) = 0 )

	'' -------------------------------------------------- generic derived, generic base

	dim as Der( of integer ) di
	di.v = 1 : di.w = 2

	dim as Der( of string ) ds
	ds.v = "a" : ds.w = "b"

	assert_( di.v = 1 )
	assert_( di.w = 2 )
	assert_( ds.v = "a" )
	assert_( ds.w = "b" )

	dim as Root( of integer ) ptr r = @di
	assert_( r->nm( ) = "Der" )
	assert_( r->tag( ) = "tag" )
	assert_( (*r is Der( of integer )) <> 0 )

	dim as Root( of string ) ptr rs = @ds
	assert_( rs->nm( ) = "Der" )
	assert_( (*rs is Der( of string )) <> 0 )

	'' The two families are not merely distinct at run time, they are rejected at
	'' COMPILE time: '*r is Der( of string )' where r is a Root( of integer ) ptr
	'' gives 'error 298: Types have no hierarchical relation', which is the
	'' stronger outcome.  Pinned by fail-is-unrelated-instantiations.bas.
	''
	'' Run-time discrimination between two instantiations is covered above, by
	'' Sq( of integer ) / Sq( of double ) under their shared concrete base.

	'' ------------------------------------------------ base pinned to one argument

	dim as Pinned( of string ) pf
	pf.v = 7 : pf.w = "x"

	dim as Root( of integer ) ptr rp = @pf
	assert_( rp->nm( ) = "Pinned" )
	assert_( rp->v = 7 )
	assert_( (*rp is Pinned( of string )) <> 0 )
	assert_( (*rp is Der( of integer )) = 0 )

	'' ---------------------------------------------------------- three levels

	dim as Leaf( of double ) lf
	lf.v = 2.5

	dim as Root( of double ) ptr rl = @lf
	assert_( rl->nm( ) = "Leaf" )
	assert_( rl->tag( ) = "middle" )     '' inherited from the middle generic
	assert_( (*rl is Leaf( of double )) <> 0 )
	assert_( (*rl is Middle( of double )) <> 0 )

	'' a Middle that is not a Leaf
	dim as Middle( of double ) md
	rl = @md
	assert_( rl->nm( ) = "Middle" )
	assert_( (*rl is Leaf( of double )) = 0 )
	assert_( (*rl is Middle( of double )) <> 0 )

	'' --------------------------------------------------------- continuation

	dim as Cont( of integer ) ci
	ci.c = 3
	p = @ci
	assert_( p->nm( ) = "Cont" )
	assert_( (*p is Cont( of integer )) <> 0 )
	assert_( (*p is Sq( of integer )) = 0 )

	'' ---------------------------------------------------------------- union

	assert_( sizeof( Pun( of double ) ) = sizeof( PlainPun ) )

	dim as Pun( of double ) u
	u.b = 0
	'' NOT 1.5: its low 32 bits are zero, so on a 32-bit target -- where
	'' INTEGER is 4 bytes and b overlaps only the low half -- b would read 0
	'' and the assertion would fail for a reason that has nothing to do with
	'' generics.  Plain FreeBASIC does the same with PlainPun.  1.3 has
	'' non-zero bits in both halves.
	u.a = 1.3
	assert_( u.b <> 0 )                 '' the fields really do overlap
