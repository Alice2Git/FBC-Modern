' TEST_MODE : COMPILE_AND_RUN_OK

'' FB.Optional( of T ) read through const: HasValue( ) and ValueOr( ) are
'' const methods.
''
'' A record with an Optional field, kept in a container whose element accessor
'' is 'const operator [] byref as const T' (xContainers' xArray, for one), could
'' not be asked whether the field is set: 'arr[i].Email.HasValue( )' was
'' error 276, 'Const UDT cannot invoke non-const method'.
''
'' Value( ) stays non-const: it returns BYREF T so that it can be written
'' through, and a const method of the same name cannot sit next to it (a
'' method cannot be overloaded on const alone, error 4).  On a const Optional
'' the value is read with ValueOr( ), which returns a copy.
'' fail-optional-const-value.bas pins that Value( ) is still refused there.

#include once "fb/optional.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------------------------ const locals

scope
	dim as const FB.Optional( of long ) some_ = FB.Some( 7l )
	dim as const FB.Optional( of long ) none_ = FB.None( of long )( )

	assert_( some_.HasValue( ) )
	assert_( none_.HasValue( ) = false )
	assert_( some_.ValueOr( -1 ) = 7 )
	assert_( none_.ValueOr( -1 ) = -1 )

	'' the default may be a const
	dim as const long d = 5
	assert_( none_.ValueOr( d ) = 5 )
end scope

'' ------------------------------------------------------------ byref const parameter

function Describe( byref o as const FB.Optional( of string ) ) as string
	if( o.HasValue( ) ) then
		return "has " & o.ValueOr( "" )
	end if
	return "none " & o.ValueOr( "(none)" )
end function

assert_( Describe( FB.Some( "ada" ) ) = "has ada" )
assert_( Describe( FB.None( of string )( ) ) = "none (none)" )

'' ------------------------------------------------------------ through a const accessor

type Person
	as string Name
	as FB.Optional( of string ) Email
end type

type People
	as Person items( 0 to 1 )
	declare const operator [] ( byval i as long ) byref as const Person
end type

const operator People.[] ( byval i as long ) byref as const Person
	return this.items( i )
end operator

function EmailOf( byref ps as const People, byval i as long ) as string
	if( ps[i].Email.HasValue( ) = false ) then
		return "-"
	end if
	return ps[i].Email.ValueOr( "" )
end function

dim as People ps
ps.items( 0 ).Name = "Ada"
ps.items( 0 ).Email = FB.Some( "ada@example.com" )
ps.items( 1 ).Name = "Bob"

assert_( EmailOf( ps, 0 ) = "ada@example.com" )
assert_( EmailOf( ps, 1 ) = "-" )

'' ------------------------------------------------------------ non-const still works

'' a const method is callable on a non-const object, and Value( ) still writes
'' through
scope
	dim as FB.Optional( of long ) o = FB.Some( 1l )
	assert_( o.HasValue( ) )
	assert_( o.ValueOr( 0 ) = 1 )
	o.Value( ) = 2
	assert_( o.ValueOr( 0 ) = 2 )

	'' ValueOr( ) is a copy: changing it changes nothing in o
	dim as long c = o.ValueOr( 0 )
	c = 9
	assert_( o.Value( ) = 2 )
end scope

'' ------------------------------------------------------------ a UDT element

type Pt
	as long x, y
end type

scope
	dim as Pt dflt
	dflt.x = -1
	dim as const FB.Optional( of Pt ) e = FB.None( of Pt )( )
	assert_( e.ValueOr( dflt ).x = -1 )

	dim as Pt p
	p.x = 3
	dim as const FB.Optional( of Pt ) s = FB.Some( p )
	assert_( s.ValueOr( dflt ).x = 3 )
end scope
