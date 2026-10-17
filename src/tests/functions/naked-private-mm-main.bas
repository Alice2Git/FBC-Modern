
'' Driver for naked-private-mm.bmk -- see that file for what this pins.

#include once "naked-private-mm.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

	'' the driver's own copy of the private naked procedure...
	assert_( NakedInc( 41 ) = 42 )

	'' ...module A's copy of it
	assert_( ModuleA( ) = 10 )

	'' ...and module A's public naked procedure
	assert_( NakedPublicDouble( 21 ) = 42 )
