' TEST_MODE : COMPILE_AND_RUN_OK

'' A NON-generic type extending a generic instantiation, inside a namespace.
''
'' The instantiation's synthetic namespace goes into the global symbol table,
'' after the namespace that uses it, so under -gen gcc the derived type's RTTI
'' -- emitted with its namespace -- named the base's RTTI before it was
'' declared:
''
''     error: '_ZTSN1GIiEE' undeclared here (not in a function)
''
'' gas64 and the asm backend do not care about declaration order.  Covered: a
'' direct child, a grandchild, a child in ANOTHER namespace, a child at
'' toplevel, IS checks and virtual destructors through the base.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long dtors

namespace N
	type B extends object
		declare virtual destructor( )
	end type
	destructor B( )
		dtors += 1
	end destructor

	type G( of T ) extends B
		as T v
	end type

	type C extends G( of long )
		as long w
		declare destructor( )
	end type
	destructor C( )
		dtors += 10
	end destructor

	type D extends C
		as long x
	end type
end namespace

namespace M
	type E extends N.G( of double )
		as long y
	end type
end namespace

type F extends N.G( of short )
	as long z
end type

dim as N.B ptr p = new N.C
assert_( *p is N.C )
assert_( *p is N.G( of long ) )
assert_( not ( *p is N.D ) )
delete p
assert_( dtors = 11 )

dtors = 0
p = new N.D
assert_( *p is N.D )
assert_( *p is N.C )
delete p
assert_( dtors = 11 )

dtors = 0
p = new M.E
assert_( *p is M.E )
assert_( *p is N.G( of double ) )
assert_( not ( *p is N.C ) )
delete p
assert_( dtors = 1 )

dtors = 0
p = new F
assert_( *p is F )
assert_( not ( *p is M.E ) )
delete p
assert_( dtors = 1 )
