' TEST_MODE : COMPILE_AND_RUN_OK

'' Lambda expressions -- non-capturing.
''
'' Sketch S.3. A lambda with no capture list lowers to a plain module-level
'' procedure plus its address, so it is type-identical to '@myproc' and passes
'' to any matching procedure pointer. That is the property the whole phase
'' exists for: every Win32-style callback API keeps working unchanged.
''
'' Capturing lambdas -- 'sub[ byref total ]( ... )' -- are a separate phase and
'' a separate file.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Fn as function( byval x as long ) as long
type CmpFn as function( byval a as long, byval b as long ) as long

declare function ApplyTo( byval f as CmpFn, byval a as long, byval b as long ) as long
declare sub EachNum( byval cb as sub( byval n as long ) )
declare function MakeAdder( ) as Fn
declare function PlusOne( byval x as long ) as long
declare sub qsort cdecl alias "qsort" _
	( byval as any ptr, byval as uinteger, byval as uinteger, byval as any ptr )

dim shared as long sideEffect

'' A lambda at MODULE level, outside any procedure.
dim shared g as Fn = function( byval x as long ) as long : return x + 100 : end function

	'' ==================================================== assignment and call

	scope
		'' one-liner, explicit procptr type
		dim d as Fn = function( byval x as long ) as long : return x * 2 : end function
		assert_( d( 21 ) = 42 )

		'' multi-line body
		dim m as Fn = _
			function( byval x as long ) as long
				return x * 3
			end function
		assert_( m( 5 ) = 15 )

		'' VAR, with the type inferred from the lambda
		var v = function( byval x as long ) as long : return x * 4 : end function
		assert_( v( 5 ) = 20 )

		'' the inferred type really is the procptr, not something else
		assert_( sizeof( v ) = sizeof( any ptr ) )
		assert_( sizeof( d ) = sizeof( any ptr ) )
	end scope

	'' ==================================================== the SUB form

	scope
		dim s as sub( byref n as long ) = sub( byref n as long ) : n *= 2 : end sub
		dim as long v = 21
		s( v )
		assert_( v = 42 )

		'' zero parameters
		dim z as sub( ) = sub( ) : sideEffect = 7 : end sub
		sideEffect = 0
		z( )
		assert_( sideEffect = 7 )
	end scope

	'' ==================================================== zero, one and several params

	scope
		dim z as function( ) as long = function( ) as long : return 99 : end function
		assert_( z( ) = 99 )

		dim one as Fn = function( byval x as long ) as long : return x : end function
		assert_( one( 3 ) = 3 )

		dim three as function( byval a as long, byval b as long, byval c as long ) as long = _
			function( byval a as long, byval b as long, byval c as long ) as long
				return a + b + c
			end function
		assert_( three( 1, 2, 3 ) = 6 )
	end scope

	'' ==================================================== BYREF params and BYREF return

	scope
		dim swap_ as sub( byref a as long, byref b as long ) = _
			sub( byref a as long, byref b as long )
				dim as long t_ = a
				a = b
				b = t_
			end sub
		dim as long p = 1, q = 2
		swap_( p, q )
		assert_( p = 2 )
		assert_( q = 1 )

		dim pick as function( byref a as long, byref b as long ) byref as long = _
			function( byref a as long, byref b as long ) byref as long
				if( a > b ) then return a
				return b
			end function
		dim as long lo = 3, hi = 9
		assert_( pick( lo, hi ) = 9 )

		'' the BYREF return really is a reference
		dim byref as long r = pick( lo, hi )
		r = 11
		assert_( hi = 11 )
	end scope

	'' ==================================================== passed as an argument

	scope
		'' inline, multi-line, mid argument list
		''
		'' Assigned first rather than written inside assert_( ): assert_ is a
		'' #define, and a macro argument cannot span lines. That is a macro
		'' limitation, not a lambda one -- the call itself is the multi-line
		'' inline form.
		dim as long got = ApplyTo( function( byval a as long, byval b as long ) as long
			return a - b
		end function, 10, 4 )
		assert_( got = 6 )

		'' a SUB argument, inline
		sideEffect = 0
		EachNum( sub( byval n as long ) : sideEffect += n : end sub )
		assert_( sideEffect = 6 )
	end scope

	'' ==================================================== returned from a function

	scope
		dim a as Fn = MakeAdder( )
		assert_( a( 4 ) = 5 )
	end scope

	'' ==================================================== module level

	scope
		assert_( g( 1 ) = 101 )
	end scope

	'' ==================================================== two lambdas stay distinct
	''
	'' Identical signatures, same scope. This is also the case that first broke:
	'' the second lambda's header replay drained the first lambda's BODY from
	'' inside itself, opening a procedure while one was already open.

	scope
		dim p as Fn = function( byval x as long ) as long : return x + 1 : end function
		dim q as Fn = function( byval x as long ) as long : return x + 2 : end function
		assert_( p( 10 ) = 11 )
		assert_( q( 10 ) = 12 )

		'' and they really are two procedures
		assert_( cast( any ptr, p ) <> cast( any ptr, q ) )
	end scope

	'' ==================================================== nested lambdas
	''
	'' The reason body capture counts depth instead of stopping at the first
	'' END: procedures cannot nest in FreeBASIC, but lambdas can, and the inner
	'' terminator would otherwise truncate the outer capture.

	scope
		dim outer_ as function( ) as Fn = _
			function( ) as Fn
				return function( byval x as long ) as long : return x * 7 : end function
			end function
		dim inner_ as Fn = outer_( )
		assert_( inner_( 6 ) = 42 )
	end scope

	'' ==================================================== a procptr RESULT type
	''
	'' The result type has parentheses of its own, which is why the header scan
	'' balances them rather than stopping at the first ')'.

	scope
		dim mk as function( ) as function( byval x as long ) as long = _
			function( ) as function( byval x as long ) as long
				return function( byval x as long ) as long : return x - 1 : end function
			end function
		assert_( mk( )( 8 ) = 7 )
	end scope

	'' ==================================================== EXIT inside a body

	scope
		sideEffect = 0
		dim e as sub( byval n as long ) = _
			sub( byval n as long )
				if( n = 1 ) then exit sub
				sideEffect = 5
			end sub
		e( 1 )
		assert_( sideEffect = 0 )
		e( 2 )
		assert_( sideEffect = 5 )
	end scope

	'' ==================================================== a real C callback
	''
	'' qsort's comparator is CDECL. Without a calling convention between the
	'' keyword and the '(' a lambda could not be used for the very APIs that
	'' motivate the feature.

	scope
		dim cmp as function cdecl( byval p1 as any ptr, byval p2 as any ptr ) as long = _
			function cdecl( byval p1 as any ptr, byval p2 as any ptr ) as long
				return *cptr( long ptr, p1 ) - *cptr( long ptr, p2 )
			end function

		dim a( 0 to 4 ) as long = { 5, 3, 1, 4, 2 }
		qsort( @a( 0 ), 5, sizeof( long ), cmp )

		for i as long = 0 to 4
			assert_( a( i ) = i + 1 )
		next
	end scope

	'' ==================================================== interchangeable with @proc

	'' A lambda and the address of a hand-written procedure are the same type
	'' and go through the same parameter.
	scope
		dim fromLambda as Fn = function( byval x as long ) as long : return x + 1 : end function
		dim fromProc as Fn = @PlusOne

		assert_( fromLambda( 1 ) = 2 )
		assert_( fromProc( 1 ) = 2 )

		'' assignable to each other
		fromProc = fromLambda
		assert_( fromProc( 5 ) = 6 )

		'' and to an array of them
		dim tb( 0 to 1 ) as Fn
		tb( 0 ) = function( byval x as long ) as long : return x * 10 : end function
		tb( 1 ) = @PlusOne
		assert_( tb( 0 )( 3 ) = 30 )
		assert_( tb( 1 )( 3 ) = 4 )
	end scope

'' ---------------------------------------------------------------- fixtures

function PlusOne( byval x as long ) as long
	return x + 1
end function

function ApplyTo( byval f as CmpFn, byval a as long, byval b as long ) as long
	return f( a, b )
end function

sub EachNum( byval cb as sub( byval n as long ) )
	for i as long = 1 to 3
		cb( i )
	next
end sub

function MakeAdder( ) as Fn
	return function( byval x as long ) as long : return x + 1 : end function
end function
