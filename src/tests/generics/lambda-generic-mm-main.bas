'' Driver for lambda-generic-mm.bmk -- see that file for what this pins.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

#include once "lambda-generic-mm.bi"

declare function LgmModuleA( ) as long
declare function LgmModuleB( ) as long

	'' 1 + 4, 10 + 2, 1 * 3, 42
	assert_( LgmModuleA( ) = 62 )
	'' 2 + 4, 10 + 2, 2 * 3, 42
	assert_( LgmModuleB( ) = 66 )

	'' and the main module's own copies, instantiated the same way
	var f = LgmPlain( 1l )
	assert_( f( 3 ) = 7 )
	assert_( LgmCapture( 2l ) = 12 )
