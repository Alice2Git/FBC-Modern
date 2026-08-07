' TEST_MODE : MULTI_MODULE_TEST

#include once "shared.bi"

'' The same instantiations as main.bas -- Box( of long ), Box( of string ),
'' Twice( of long ) and operator +( of long ) -- reached independently here.

function secondSum( ) as long
	dim a as Box( of long )
	dim b as Box( of long )
	a.set_( 10 )
	b.set_( 32 )

	dim c as Box( of long ) = a + b
	return c.get_( ) + Twice( 5L ) + a.twice_( )
end function

function secondText( ) as string
	dim s as Box( of string )
	s.set_( "second" )
	return s.get_( )
end function
