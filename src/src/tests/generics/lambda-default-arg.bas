' TEST_MODE : COMPILE_AND_RUN_OK

'' A lambda as the DEFAULT VALUE of a generic procedure's parameter.
''
'' A generic's header is captured as tokens, and the capture stopped at the
'' first EOL or ':'. A lambda default value carries ':' between its statements
'' and real EOLs when written over several lines, so the header was cut in half
'' mid-parameter-list: "error 3: Expected End-of-Line, found ')'", and what was
'' left of the list was parsed as statements. Both forms work outside generics.
''
'' The capture now tracks '(' depth and only ends the header at depth 0.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type LongFn as function( byval x as long ) as long

'' one-liner default, with the ':' that used to end the capture
function Apply( of T )( byref a as T, byval f as LongFn = function( byval x as long ) as long : return x + 1 : end function ) as long
	return f( a )
end function

'' multi-line default: real EOLs inside the parameter list
function ApplyML( of T )( byref a as T, byval f as LongFn = _
		function( byval x as long ) as long
			return x + 2
		end function ) as long
	return f( a )
end function

'' the default is used...
assert_( Apply( of long )( 41 ) = 42 )
assert_( ApplyML( of long )( 40 ) = 42 )

'' ...and so is an explicit argument, lambda or not
assert_( Apply( of long )( 41, function( byval x as long ) as long : return x - 1 : end function ) = 40 )
assert_( ApplyML( of long )( 41, function( byval x as long ) as long : return x * 2 : end function ) = 82 )

'' a second instantiation replays the same header again
assert_( Apply( of short )( cshort( 41 ) ) = 42 )
assert_( Apply( of double )( 1.5 ) = 3 )

'' type-argument inference, with every argument written out
assert_( Apply( 41, function( byval x as long ) as long : return x + 10 : end function ) = 51 )

'' a plain default value still behaves
function AddN( of T )( byref a as T, byval n as long = 1 ) as long
	return a + n
end function

assert_( AddN( of long )( 41 ) = 42 )
assert_( AddN( 41, 1 ) = 42 )

'' a one-liner generic still splits where it always did: the ':' after the
'' header's ')' is at depth 0 and ends the header, not the body
dim shared as double olsum
sub OneLiner( of T )( byval x as T ) : olsum += x : end sub
OneLiner( 7 )
OneLiner( 2.5 )
assert_( olsum = 9.5 )
