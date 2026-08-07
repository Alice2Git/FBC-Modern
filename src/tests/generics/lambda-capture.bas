' TEST_MODE : COMPILE_AND_RUN_OK

'' Lambda expressions -- CAPTURING.
''
'' 'sub[ byref total ]( ... ) ... end sub' synthesises a closure struct holding
'' one field per capture, with the body as its __FBINVOKE. The value of the
'' expression is a closure object living in the enclosing scope -- no heap, no
'' allocation, destroyed with the frame.
''
'' Every capture carries an explicit BYVAL or BYREF. In a language with manual
'' lifetimes the mode IS the lifetime question, and inferring it is how a
'' closure ends up holding a reference to a destroyed frame.
''
'' A capturing lambda is NOT a procedure pointer -- it has state and a procptr
'' has nowhere to put it. It reaches an API through a GENERIC parameter, which
'' is what FB.ForEach exists for.

#include once "fb/array.bi"
#include once "fb/optional.bi"
using FB

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' A type that counts itself, for capture-by-value destructor balance.
dim shared as long liveCounted, madeCounted

type Counted
	as long v
	declare constructor( )
	declare constructor( byval n as long )
	declare constructor( byref rhs as Counted )
	declare operator let( byref rhs as Counted )
	declare destructor( )
end type

constructor Counted( )
	this.v = 0 : liveCounted += 1 : madeCounted += 1
end constructor
constructor Counted( byval n as long )
	this.v = n : liveCounted += 1 : madeCounted += 1
end constructor
constructor Counted( byref rhs as Counted )
	this.v = rhs.v : liveCounted += 1 : madeCounted += 1
end constructor
operator Counted.let( byref rhs as Counted )
	this.v = rhs.v
end operator
destructor Counted( )
	liveCounted -= 1
end destructor

'' Generic procedures cannot be forward-declared -- 'declare sub Apply( of F )'
'' is refused -- so these are defined before use rather than at the bottom.
sub Apply( of F )( byval n as long, byref f as F )
	for i as long = 1 to n
		f( i )
	next
end sub

function ApplyR( of F )( byval n as long, byref f as F ) as long
	return f( n )
end function

	'' ==================================================== BYREF capture

	scope
		dim as long total = 0
		var c = sub[ byref total ]( byval item as long )
			total += item
		end sub

		c( 5 )
		c( 7 )
		assert_( total = 12 )

		'' writes to the captured local are visible to the closure too
		total = 100
		c( 1 )
		assert_( total = 101 )
	end scope

	'' ==================================================== BYVAL capture is a snapshot

	scope
		dim as long bias = 10
		var a = function[ byval bias ]( byval x as long ) as long
			return x + bias
		end function

		'' taken when the lambda expression was EVALUATED, so a later write to
		'' the source is not seen
		bias = 999
		assert_( a( 5 ) = 15 )
		assert_( a( 0 ) = 10 )
		assert_( bias = 999 )
	end scope

	'' ==================================================== several captures, mixed modes

	scope
		dim as long hits = 0
		dim as string needle = "err"

		var m = sub[ byref hits, byval needle ]( byref row as string )
			if( instr( row, needle ) ) then hits += 1
		end sub

		m( "an err here" )
		m( "fine" )
		m( "err again" )
		assert_( hits = 2 )

		'' the BYVAL string really is a copy
		needle = "zzz"
		m( "err once more" )
		assert_( hits = 3 )
	end scope

	'' ==================================================== independent state
	''
	'' Two closures over different locals. This is the case a single static
	'' thunk would get wrong: it would share one environment.

	scope
		dim as long n1 = 0, n2 = 0
		var i1 = sub[ byref n1 ]( ) : n1 += 1 : end sub
		var i2 = sub[ byref n2 ]( ) : n2 += 10 : end sub

		i1( )
		i1( )
		i2( )

		assert_( n1 = 2 )
		assert_( n2 = 10 )
	end scope

	'' ==================================================== called every way

	scope
		dim as long bias = 1
		var f = function[ byval bias ]( byval x as long ) as long : return x + bias : end function

		'' assigned
		dim as long r = f( 5 )
		assert_( r = 6 )

		'' inside a larger expression
		assert_( f( 5 ) + 1 = 7 )
		assert_( f( f( 1 ) ) = 3 )

		'' zero arguments, in statement position -- a different parser branch
		'' from 'f( 1 )', because the look-ahead after '(' is ')'
		dim as long ticks = 0
		var t = sub[ byref ticks ]( ) : ticks += 1 : end sub
		t( )
		t( )
		assert_( ticks = 2 )
	end scope

	'' ==================================================== an EMPTY capture list

	'' '[ ]' is the NON-capturing form, not a closure with no captures: a
	'' fieldless struct is refused by FreeBASIC, and it should mean what
	'' 'sub( ... )' means anyway. So it is still a procedure pointer.
	scope
		dim e as function( byval x as long ) as long = _
			function[ ]( byval x as long ) as long : return x * 2 : end function
		assert_( e( 21 ) = 42 )
		assert_( sizeof( e ) = sizeof( any ptr ) )
	end scope

	'' ==================================================== through a generic parameter
	''
	'' The only way a capturing lambda reaches an API, and the sketch's own
	'' motivating example.

	scope
		dim as long sum_ = 0
		Apply( 4, sub[ byref sum_ ]( byval v as long ) : sum_ += v : end sub )
		assert_( sum_ = 10 )

		'' a NON-capturing lambda goes through the same generic unchanged
		dim as long seen = 0
		Apply( 3, sub( byval v as long ) : end sub )
		assert_( seen = 0 )

		'' a function through a generic, with a result.
		'' Assigned first: assert_ is a #define and a macro argument cannot span
		'' lines -- a macro limitation, not a lambda one.
		dim as long bias = 2
		dim as long got = ApplyR( 3, function[ byval bias ]( byval v as long ) as long
			return v + bias
		end function )
		assert_( got = 5 )
	end scope

	'' ==================================================== FB.ForEach

	scope
		dim nums as Array( of long )
		for i as long = 1 to 4
			nums.Push( i )
		next

		dim as longint total = 0
		ForEach( nums, sub[ byref total ]( byref v as long ) : total += v : end sub )
		assert_( total = 10 )

		'' elements are passed BYREF, so a lambda can modify them in place
		ForEach( nums, sub( byref v as long ) : v *= 2 : end sub )
		assert_( nums[ 0 ] = 2 )
		assert_( nums[ 3 ] = 8 )

		'' capturing a string as well
		dim as string sep = "-"
		dim as string out_ = ""
		ForEach( nums, sub[ byref out_, byval sep ]( byref v as long )
			out_ &= str( v ) & sep
		end sub )
		assert_( out_ = "2-4-6-8-" )
	end scope

	'' ==================================================== capturing a UDT

	type Pt
		as long x, y
	end type

	scope
		dim p as Pt
		p.x = 3 : p.y = 4

		dim as long got = 0
		var c = sub[ byref p, byref got ]( )
			got = p.x + p.y
			p.x = 99
		end sub

		c( )
		assert_( got = 7 )
		assert_( p.x = 99 )

		'' and BYVAL, which copies the UDT
		dim q as Pt
		q.x = 1 : q.y = 2
		dim as long got2 = 0
		var d = sub[ byval q, byref got2 ]( )
			got2 = q.x + q.y
		end sub
		q.x = 100
		d( )
		assert_( got2 = 3 )
	end scope

	'' ==================================================== capturing a CONTAINER
	''
	'' The closure is declared as a GENERIC over its capture types and then
	'' instantiated from the captured symbols' dtype/subtype, so a capture's
	'' type is never written as text. That is what makes this section possible:
	'' naming the type could not express a container, because a generic
	'' instantiation prints as its mangled internal name and
	''     var c = sub[ byref a ]( ) ...      '' a is an Array( of long )
	'' failed with 'error 14: Expected identifier, found $'.

	scope
		dim src as Array( of long )
		src.Push( 7 )

		dim as long got = 0
		var c = sub[ byref src, byref got ]( )
			got = src[ 0 ]
			src.Push( 9 )
		end sub

		c( )
		assert_( got = 7 )
		assert_( src.Count( ) = 2 )      '' the closure mutated the caller's container
		assert_( src[ 1 ] = 9 )
	end scope

	'' BYVAL a container is a DEEP COPY taken at evaluation, so a later push to
	'' the source is not seen.
	scope
		dim orig as Array( of long )
		orig.Push( 1 )

		dim as long n = 0
		var d = sub[ byval orig, byref n ]( )
			n = orig.Count( )
		end sub

		orig.Push( 2 )
		d( )
		assert_( n = 1 )
		assert_( orig.Count( ) = 2 )
	end scope

	'' and an Optional, which is a generic too
	scope
		dim o as Optional( of long ) = Some( 5L )
		dim as long ov = 0
		var e = sub[ byref o, byref ov ]( )
			ov = o.Value( )
		end sub
		e( )
		assert_( ov = 5 )
	end scope

	'' ==================================================== destructor balance

	'' A BYVAL capture is a real copy stored in the closure, so it must be
	'' constructed once and destroyed once. Asserted after the scope closes.
	liveCounted = 0
	madeCounted = 0

	scope
		dim c as Counted = Counted( 5 )

		dim as long got = 0
		var f = sub[ byval c, byref got ]( )
			got = c.v
		end sub

		f( )
		assert_( got = 5 )
		assert_( madeCounted >= 2 )      '' the original, plus the closure's copy
	end scope

	assert_( liveCounted = 0 )

	'' and a BYREF capture must NOT copy it
	liveCounted = 0
	madeCounted = 0

	scope
		dim c as Counted = Counted( 3 )
		dim as long made0 = madeCounted

		dim as long got = 0
		var f = sub[ byref c, byref got ]( )
			got = c.v
		end sub

		f( )
		assert_( got = 3 )
		assert_( madeCounted = made0 )   '' nothing constructed by the capture
	end scope

	assert_( liveCounted = 0 )

