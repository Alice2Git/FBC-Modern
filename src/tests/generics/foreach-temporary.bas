' TEST_MODE : COMPILE_AND_RUN_OK

'' FOR EACH over a temporary collection keeps it alive until the loop ends.
''
'' 'for each x in F( )', with F returning the collection BY VALUE, destroyed
'' the returned temporary at the end of the FOR EACH statement itself -- right
'' after GetIterator( ) -- so an iterator pointing into the collection read
'' freed memory: no iterations, empty strings or a crash depending on the
'' backend.  The temporary now lives as long as the loop, like C++'s range-for,
'' and is destroyed exactly once when the loop is left, however it is left.

#include once "fb/array.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' live collections, so the tests can see when a temporary dies
dim shared as long live

type CollIt
	as long ptr p
	as long i, n
	declare function IsValid( ) as boolean
	declare function Value( ) byref as long
	declare sub MoveNext( )
end type
function CollIt.IsValid( ) as boolean : return this.i < this.n : end function
function CollIt.Value( ) byref as long
	'' the collection the iterator walks must still exist
	assert_( live > 0 )
	return this.p[ this.i ]
end function
sub CollIt.MoveNext( ) : this.i += 1 : end sub

type Coll
	as long ptr p
	as long n
	declare constructor( )
	declare constructor( byval count as long )
	declare constructor( byref other as const Coll )
	declare operator let( byref other as const Coll )
	declare destructor( )
	declare function GetIterator( ) as CollIt
end type
constructor Coll( )
	live += 1
end constructor
constructor Coll( byval count as long )
	live += 1
	n = count
	p = callocate( n, sizeof( long ) )
	for i as long = 0 to n - 1 : p[ i ] = i + 1 : next
end constructor
constructor Coll( byref other as const Coll )
	live += 1
	n = other.n
	p = callocate( n, sizeof( long ) )
	for i as long = 0 to n - 1 : p[ i ] = other.p[ i ] : next
end constructor
operator Coll.let( byref other as const Coll )
	deallocate( p )
	n = other.n
	p = callocate( n, sizeof( long ) )
	for i as long = 0 to n - 1 : p[ i ] = other.p[ i ] : next
end operator
destructor Coll( )
	'' poison before freeing, so a late reader sees garbage, not old data
	for i as long = 0 to n - 1 : p[ i ] = -1000 : next
	deallocate( p )
	p = 0
	live -= 1
end destructor
function Coll.GetIterator( ) as CollIt
	dim r as CollIt : r.p = this.p : r.n = this.n : return r
end function

function MakeColl( byval count as long ) as Coll
	return Coll( count )
end function

'' a pointer, so the collection is not counted as live before its test
dim shared as Coll ptr keeper
function KeeperRef( ) byref as Coll
	return *keeper
end function

'' ---------------------------------------------- a function's result

scope
	dim as long sum = 0, iters = 0
	for each x in MakeColl( 4 )
		assert_( live = 1 )
		sum += x
		iters += 1
	next
	assert_( iters = 4 )
	assert_( sum = 1 + 2 + 3 + 4 )
	'' destroyed when the loop ended, exactly once
	assert_( live = 0 )
end scope

'' ------------------------------------------------- EXIT FOR leaves early

scope
	dim as long iters = 0
	for each x in MakeColl( 5 )
		iters += 1
		if( x = 2 ) then exit for
	next
	assert_( iters = 2 )
	assert_( live = 0 )
end scope

'' ------------------------------- CONTINUE FOR and an explicit element type

scope
	dim as long sum = 0
	for each x as long in MakeColl( 4 )
		if( x mod 2 ) then continue for
		sum += x
	next
	assert_( sum = 2 + 4 )
	assert_( live = 0 )
end scope

'' ---------------------------------------- a constructor call is a temporary

scope
	dim as long sum = 0
	for each x in Coll( 3 )
		sum += x
	next
	assert_( sum = 6 )
	assert_( live = 0 )
end scope

'' -------------------------------------------------- nested temporaries

scope
	dim as long sum = 0
	for each a in MakeColl( 3 )
		for each b in MakeColl( 2 )
			assert_( live = 2 )
			sum += a * b
		next
		assert_( live = 1 )
	next
	assert_( sum = (1 + 2 + 3) * (1 + 2) )
	assert_( live = 0 )
end scope

'' ------------------------------------- RETURN from inside the loop body

function FirstOver( byval limit as long ) as long
	for each x in MakeColl( 6 )
		if( x > limit ) then return x
	next
	return -1
end function

scope
	assert_( FirstOver( 3 ) = 4 )
	assert_( live = 0 )
	assert_( FirstOver( 10 ) = -1 )
	assert_( live = 0 )
end scope

'' ------------------------- a variable is not copied, and outlives the loop

scope
	dim as Coll c = Coll( 3 )
	assert_( live = 1 )
	dim as long sum = 0
	for each x in c
		assert_( live = 1 )
		sum += x
	next
	assert_( sum = 6 )
	assert_( live = 1 )
end scope
assert_( live = 0 )

'' --------- a BYREF result is the original, not a copy: writes are visible

keeper = new Coll( 3 )
scope
	assert_( live = 1 )
	for each byref x in KeeperRef( )
		assert_( live = 1 )
		x *= 10
	next
	assert_( live = 1 )
	assert_( keeper->p[ 0 ] = 10 andalso keeper->p[ 1 ] = 20 andalso keeper->p[ 2 ] = 30 )
end scope
delete keeper
assert_( live = 0 )

'' --------------------------- FB.Array of strings returned by a function

function Items( ) as FB.Array( of string )
	dim a as FB.Array( of string )
	for i as long = 1 to 3 : a.Push( "item" & i & string( 40, "x" ) ) : next
	return a
end function

scope
	dim as string seen
	for each it in Items( )
		seen &= left( it, 5 ) & ";"
	next
	assert_( seen = "item1;item2;item3;" )
end scope
