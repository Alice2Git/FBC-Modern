
'' Driver for hash-mm.bmk -- see that file for what this pins.

#include once "fb/map.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

declare function HashModuleA( ) as long
declare function HashModuleB( ) as long

	assert_( HashModuleA( ) = 3 )
	assert_( HashModuleB( ) = 3 )

	'' and the driver's own instantiation, a third copy of the overloads
	dim as FB.Map( of string, long ) m
	m.Put( "k", 1 )
	assert_( m.Count( ) = 1 )
