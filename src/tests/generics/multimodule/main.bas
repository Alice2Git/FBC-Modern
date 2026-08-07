' TEST_MODE : MULTI_MODULE_TEST

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

#include once "shared.bi"

declare function secondSum( ) as long
declare function secondText( ) as string

	'' the same instantiations as second.bas, reached here too
	dim a as Box( of long )
	dim b as Box( of long )
	a.set_( 1 )
	b.set_( 2 )

	dim c as Box( of long ) = a + b
	assert_( c.get_( ) = 3 )
	assert_( a.twice_( ) = 2 )
	assert_( Twice( 7L ) = 14 )

	dim s as Box( of string )
	s.set_( "main" )
	assert_( s.get_( ) = "main" )

	'' the other module's copies of the SAME instantiations still work, which
	'' is what proves the surviving copy is a correct one and not a stub
	assert_( secondSum( ) = 42 + 10 + 20 )
	assert_( secondText( ) = "second" )

	'' an instantiation only ONE module reaches still links
	dim d as Box( of double )
	d.set_( 1.5 )
	assert_( d.twice_( ) = 3.0 )
