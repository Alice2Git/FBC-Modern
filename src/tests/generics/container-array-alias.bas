' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Array( of T ) -- an argument that ALIASES the array's own storage.
''
'' Push( byref v ) used to Reserve first and read v second.  When the push has
'' to grow, Reserve redims, and a v that pointed INTO the array -- 'a.Push(
'' a[ 0 ] )' -- was read from freed memory: a string element came back as
'' garbage or the program segfaulted.  Insert already copied v first.
''
'' Strings long enough to live on the heap, so a dangling read cannot pass by
'' accident; every case is asserted both on a push that grows and on one that
'' does not.

#include once "fb/array.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

const LONGSTR = "a-string-long-enough-to-be-on-the-heap-not-inline"

scope
	'' the push that GROWS: the array is full, so Push must reallocate
	dim a as Array( of string )
	a.Push( LONGSTR )
	while( a.Count( ) < a.Capacity( ) )
		a.Push( "x" & a.Count( ) )
	wend
	dim as long n = a.Count( )
	a.Push( a[ 0 ] )
	assert_( a.Count( ) = n + 1 )
	assert_( a[ n ] = LONGSTR )
	assert_( a[ 0 ] = LONGSTR )

	'' and the last element, which is the other end of the old block
	while( a.Count( ) < a.Capacity( ) )
		a.Push( "y" & a.Count( ) )
	wend
	n = a.Count( )
	dim as string lastv = a[ n - 1 ]
	a.Push( a[ n - 1 ] )
	assert_( a[ n ] = lastv )
end scope

scope
	'' the push that does NOT grow still aliases correctly
	dim a as Array( of string )
	a.Reserve( 16 )
	a.Push( LONGSTR )
	a.Push( a[ 0 ] )
	assert_( a.Count( ) = 2 )
	assert_( a[ 1 ] = LONGSTR )
end scope

scope
	'' repeated self-pushes across several reallocations
	dim a as Array( of string )
	a.Push( LONGSTR )
	for i as long = 1 to 200
		a.Push( a[ i - 1 ] )
	next
	assert_( a.Count( ) = 201 )
	for i as long = 0 to 200
		assert_( a[ i ] = LONGSTR )
	next
end scope

scope
	'' Insert, which was already right, stays right on the growing path
	dim a as Array( of string )
	a.Push( LONGSTR )
	while( a.Count( ) < a.Capacity( ) )
		a.Push( "z" & a.Count( ) )
	wend
	a.Insert( 0, a[ 0 ] )
	assert_( a[ 0 ] = LONGSTR )
	assert_( a[ 1 ] = LONGSTR )
end scope

scope
	'' a type with a destructor: the copy must balance
	dim a as Array( of Array( of long ) )
	dim inner as Array( of long )
	inner.Push( 42 )
	a.Push( inner )
	while( a.Count( ) < a.Capacity( ) )
		a.Push( inner )
	wend
	a.Push( a[ 0 ] )
	assert_( a[ a.Count( ) - 1 ].Count( ) = 1 )
	assert_( a[ a.Count( ) - 1 ][ 0 ] = 42 )
end scope
