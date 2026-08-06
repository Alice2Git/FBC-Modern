' TEST_MODE : COMPILE_AND_RUN_OK

'' First working instantiation: a generic's captured body is replayed once per
'' distinct type-argument list, with the type parameters bound as TYPEDEFs in a
'' synthetic namespace, and the result used as an ordinary type.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T value
end type

type Pair( of K, V )
	as K k
	as V v
end type

	'' a scalar argument
	dim b as Box( of long )
	b.value = 7
	assert_( b.value = 7 )

	'' a string argument -- exercises a type with a ctor/dtor
	dim s as Box( of string )
	s.value = "hi"
	assert_( s.value = "hi" )

	'' The same argument list must yield the SAME type, not a second
	'' structurally-identical one: if the instantiation cache misses, this
	'' assignment does not compile.
	dim b2 as Box( of long )
	b2 = b
	assert_( b2.value = 7 )

	'' two type parameters
	dim p as Pair( of long, string )
	p.k = 42
	p.v = "world"
	assert_( p.k = 42 )
	assert_( p.v = "world" )

	'' nested: the inner instantiation happens while the outer one's argument
	'' list is still being parsed
	dim n as Box( of Box( of long ) )
	n.value.value = 99
	assert_( n.value.value = 99 )

	'' a UDT argument
	type Plain
		as integer i
	end type
	dim u as Box( of Plain )
	u.value.i = 5
	assert_( u.value.i = 5 )

	'' distinct argument lists are unrelated types, and both work
	dim d as Box( of double )
	d.value = 2.5
	assert_( d.value = 2.5 )
	assert_( b.value = 7 )
