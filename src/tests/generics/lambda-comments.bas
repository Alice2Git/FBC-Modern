' TEST_MODE : COMPILE_AND_RUN_OK

'' Comments inside a lambda's body are not part of it.
''
'' The body is captured token by token up to its matching END SUB|FUNCTION.  The
'' capture used to record comments as tokens too, so the words of a comment were
'' examined like code: an 'end sub' in a comment ended the lambda there, and the
'' rest of the body was parsed outside it.  A comment right after the header
'' also sits on the header's line, where the replay text now continues with the
'' capture aliases and a ':', and must not swallow them.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim as long n = 0

'' 'end sub' in a comment, capturing
var f1 = sub[ byref n ]( ) '' the header's comment, then end sub
	n += 1 '' end sub
	'' end sub
	rem end sub
	n += 10
end sub
f1( )
assert_( n = 11 )

'' a lambda-looking 'sub(' in a comment must not open a nested lambda
var f2 = sub[ byref n ]( )
	'' var g = sub( ) -- not a lambda
	n += 100
end sub
f2( )
assert_( n = 111 )

'' not capturing, a function
var f3 = function( byval x as long ) as long '' end function
	'' end function
	return x * 2 '' end function
end function
assert_( f3( 21 ) = 42 )

'' one-line bodies, with and without captures
var f4 = sub[ byref n ]( ) : n += 1000 : end sub '' end sub
f4( )
assert_( n = 1111 )
var f5 = function( byval x as long ) as long : return x + 1 : end function
assert_( f5( 1 ) = 2 )

'' inside a generic member body
type Box( of T )
	as T v
	declare function Run( ) as T
end type
function Box( of T ).Run( ) as T
	dim as T acc = 0, x = v
	var add = sub[ byref acc, byval x ]( ) '' end sub
		'' end sub
		acc += x
	end sub
	add( )
	add( )
	return acc
end function
dim as Box( of long ) b
b.v = 7
assert_( b.Run( ) = 14 )
