'' Driver for lambda-mm.bmk -- see that file for what this pins.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

declare function ModuleA( ) as long
declare function ModuleB( ) as long
declare function ModuleACapture( ) as long
declare function ModuleBCapture( ) as long

	'' each module's non-capturing lambda is its own procedure
	assert_( ModuleA( ) = 11 )
	assert_( ModuleB( ) = 22 )

	'' and so is each module's closure
	assert_( ModuleACapture( ) = 10 )
	assert_( ModuleBCapture( ) = 20 )
