' TEST_MODE : COMPILE_AND_RUN_OK

'' Operators and properties as members of a generic type.
''
'' Almost all of this rides the Phase 5 member-body path unchanged -- capture the
'' body once, replay it once per instantiation -- and was found already working
'' when Phase 8 probed before writing anything.  What is pinned here is that it
'' KEEPS working, plus the one thing that did not:
''
''     declare operator next( byref cond as Ctr( of T ) ) as integer
''     error 142: Invalid parameter type, it must be the same as the parent
''                TYPE/CLASS
''
'' While a generic's body is being replayed the instantiation cache holds a
'' FORWARD REFERENCE, so that a self-referential 'Node( of T ) ptr' terminates.
'' But once symbStructBegin has published the real struct a self-reference has to
'' get THAT one: some parameter checks compare symbol identity rather than the
'' resolved type, and reject the forward reference even though it prints
'' identically.  Plain FreeBASIC never meets this, because inside 'type Ctr' the
'' name Ctr is already bound to the real symbol.
''
'' The FOR/STEP/NEXT trio is the case that needs it, and needs it three times
'' over, so it is the test.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------------------- indexing and casting

type Arr( of T )
	as T e( 0 to 3 )
	declare operator [] ( byval i as integer ) byref as T
	declare operator cast( ) as integer
	declare property first( ) as T
	declare property first( byval x as T )
end type

operator Arr( of T ).[] ( byval i as integer ) byref as T
	return this.e( i )
end operator

operator Arr( of T ).cast( ) as integer
	return 4
end operator

property Arr( of T ).first( ) as T
	return this.e( 0 )
end property

property Arr( of T ).first( byval x as T )
	this.e( 0 ) = x
end property

'' ---------------------------------------------------------------- a self op

type Acc( of T )
	as T v
	declare operator += ( byval x as T )
end type

operator Acc( of T ).+= ( byval x as T )
	this.v += x
end operator

'' ------------------------------------- for/step/next, the self-reference case

type Ctr( of T )
	as T v
	declare constructor( )
	declare constructor( byval v as T )
	declare operator for( )
	declare operator step( )
	declare operator next( byref cond as Ctr( of T ) ) as integer
end type

constructor Ctr( of T )( )
	this.v = 0
end constructor

constructor Ctr( of T )( byval v as T )
	this.v = v
end constructor

operator Ctr( of T ).for( )
end operator

operator Ctr( of T ).step( )
	this.v += 1
end operator

operator Ctr( of T ).next( byref cond as Ctr( of T ) ) as integer
	return this.v <= cond.v
end operator

	'' -------------------------------------------------------------- indexing

	dim as Arr( of integer ) ai
	ai[ 0 ] = 10
	ai[ 3 ] = 40
	assert_( ai[ 0 ] = 10 )
	assert_( ai[ 3 ] = 40 )

	dim as Arr( of string ) as_
	as_[ 1 ] = "hi"
	assert_( as_[ 1 ] = "hi" )

	'' cast, on both instantiations
	assert_( cint( ai ) = 4 )
	assert_( cint( as_ ) = 4 )

	'' -------------------------------------------------------------- property

	ai.first = 99
	assert_( ai.first = 99 )

	as_.first = "zz"
	assert_( as_.first = "zz" )

	'' --------------------------------------------------------------- self op

	dim as Acc( of integer ) acc
	acc.v = 1
	acc += 5
	assert_( acc.v = 6 )

	dim as Acc( of double ) accd
	accd.v = 0.5
	accd += 0.25
	assert_( accd.v = 0.75 )

	'' -------------------------------------------------------------- for loop

	dim as integer total = 0
	for i as Ctr( of integer ) = Ctr( of integer )( 1 ) to Ctr( of integer )( 5 )
		total += i.v
	next
	assert_( total = 15 )

	'' a second instantiation drives the same three operators again
	dim as double dtotal = 0
	for i as Ctr( of double ) = Ctr( of double )( 1 ) to Ctr( of double )( 3 )
		dtotal += i.v
	next
	assert_( dtotal = 6 )
