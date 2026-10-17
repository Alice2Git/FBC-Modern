' TEST_MODE : COMPILE_AND_RUN_OK

'' Two generic global operators with the SAME symbol, for two different
'' generic types, instantiated for the same type arguments.
''
''     operator = ( of T )( byref a as const H( of T ), ... ) as integer
''     operator = ( of T )( byref a as const G( of T ), ... ) as integer
''
'' Whichever was used second for '( of long )' failed with error 20.  Every
'' generic operator had the internal name __FBGENOP<op>, so both built the
'' same instantiation key text and the second instantiation's synthetic
'' namespace collided with the first's: symbAddNamespace() refused it and the
'' operator was never registered.  The internal name is now unique to the
'' declaration.
''
'' Reported by xSmartPtr as b02.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type H( of T )
	as T ptr p_
end type

operator = ( of T )( byref a as const H( of T ), byref b as const H( of T ) ) as integer
	return a.p_ = b.p_
end operator

operator <> ( of T )( byref a as const H( of T ), byref b as const H( of T ) ) as integer
	return a.p_ <> b.p_
end operator

type G( of T )
	as T ptr p_
end type

operator = ( of T )( byref a as const G( of T ), byref b as const G( of T ) ) as integer
	return a.p_ = b.p_
end operator

operator <> ( of T )( byref a as const G( of T ), byref b as const G( of T ) ) as integer
	return a.p_ <> b.p_
end operator

'' a third, unary, with the same token as a binary one of the others
operator - ( of T )( byref a as const G( of T ) ) as integer
	return -1
end operator

operator - ( of T )( byref a as const H( of T ) ) as integer
	return -2
end operator

	dim as long x, y

	dim as G( of long ) a, b
	assert_( a = b )
	b.p_ = @x
	assert_( a <> b )

	dim as H( of long ) c, d
	assert_( c = d )
	d.p_ = @y
	assert_( c <> d )
	c.p_ = @y
	assert_( c = d )

	'' and again for another argument list, both orders
	dim as H( of short ) e, f
	dim as G( of short ) g, h
	assert_( e = f )
	assert_( g = h )

	assert_( -a = -1 )
	assert_( -c = -2 )
	assert_( -g = -1 )
	assert_( -e = -2 )
