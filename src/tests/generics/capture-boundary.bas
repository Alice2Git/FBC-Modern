' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic declaration produces no code; its body is captured verbatim and
'' replayed per instantiation.  The thing most likely to go wrong in the
'' capture is consuming the wrong number of tokens, which is silent: too few
'' and the leftovers are parsed as garbage, too many and later declarations
'' vanish.
''
'' Every case here therefore puts ordinary code AFTER the generic and checks it
'' still works.  That is the assertion -- the generic itself is never used.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T value
end type

dim shared as long plain = 1

type Pair( of K, V )
	as K k
	as V v
end type

dim shared as long twoparams = 2

'' an inner anonymous union: 'end union' must not be mistaken for the
'' generic's own terminator, and the 'union' token after 'end' must not be
'' counted as opening a new block
type WithUnion( of T )
	union
		as T a
		as integer b
	end union
	as integer tail
end type

dim shared as long innerunion = 3

'' a nested named enum, same hazard
type WithEnum( of T )
	enum E
		one
		two
	end enum
	as T v
end type

dim shared as long innerenum = 4

'' fields literally named 'end' and 'type' -- hTypeBody disambiguates these by
'' look-ahead and the capture has to agree, or it stops in the wrong place
type OddFields( of T )
	end as integer
	type as integer
	as T v
end type

dim shared as long oddfields = 5

'' a header clause after the (of ...) list is captured too, and simply
'' re-parsed at instantiation
type Parent
	as integer b
end type

type Derived( of T ) extends Parent
	as T v
end type

dim shared as long withextends = 6

'' 'end type' inside a comment must not terminate the body
type WithComment( of T )
	' end type
	as T v
end type

dim shared as long withcomment = 7

union Bag( of T )
	as T v
	as integer i
end union

dim shared as long asunion = 8

type WithProto( of T )
	declare sub push( byval v as T )
	as T v
end type

dim shared as long withproto = 9

'' generics nest in namespaces like any other declaration
namespace ns
	type Inner( of T )
		as T v
	end type
end namespace

dim shared as long innamespace = 10

	assert_( plain = 1 )
	assert_( twoparams = 2 )
	assert_( innerunion = 3 )
	assert_( innerenum = 4 )
	assert_( oddfields = 5 )
	assert_( withextends = 6 )
	assert_( withcomment = 7 )
	assert_( asunion = 8 )
	assert_( withproto = 9 )
	assert_( innamespace = 10 )
