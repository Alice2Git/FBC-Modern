'' Where an error inside a lambda is reported.
''
'' A lambda's body is compiled by replaying its captured text inside text the
'' compiler writes itself: the procedure's name, and for a capturing lambda the
'' closure struct and one alias per capture.  Every line of that used to push
'' the body down -- an error on a closure's first body line was reported five
'' lines further on, and quoted whatever line that was.  The line and the quote
'' must both be the offending line's own.

#print === a closure, one capture ===
sub oneCapture( )
	dim as long k = 0
	var f = sub[ byref k ]( )
		k += nothere1
	end sub
	f( )
end sub

#print === a closure, two captures, a continued header, a comment line ===
sub twoCaptures( )
	dim as long a = 0, b = 0
	var g = sub[ byref a, byval b ] _
		( byval x as long )

		'' a comment line
		a += x + b + nothere2
	end sub
	g( 1 )
end sub

#print === a closure, a comment after the header ===
sub commentAfterHeader( )
	dim as long k = 0
	var f = sub[ byref k ]( ) '' the header's comment
		k += nothere3
	end sub
	f( )
end sub

#print === a one-line closure ===
sub oneLine( )
	dim as long k = 0
	var f = sub[ byref k ]( ) : k += nothere4 : end sub
	f( )
end sub

#print === a closure header ===
sub badHeader( )
	dim as long k = 0
	var f = sub[ byref k ] _
		( byval x as NoSuchType )
		k += x
	end sub
end sub

#print === a closure inside a closure ===
sub nested( )
	dim as long k = 0
	var f = sub[ byref k ]( )
		var g = function[ byval k ]( ) as long
			return k + nothere5
		end function
		k += g( )
	end sub
	f( )
end sub

#print === a lambda without captures ===
var h = function( byval x as long ) as long

	return x + nothere6
end function

#print === lambdas inside a generic member body ===
type Box( of T )
	v as T
	declare sub Run( )
end type
sub Box( of T ).Run( )
	dim as T q = v
	var c = sub[ byref q ]( )
		q += nothere7
	end sub
	c( )
	var d = function( byval y as T ) as T
		return y + nothere8
	end function
end sub
dim as Box( of long ) bx
bx.Run( )

#print === a closure inside a generic procedure ===
function Gen( of T )( byval a as T ) as T
	var q = function[ byval a ]( byval y as T ) as T
		return y + a + nothere9
	end function
	return q( a )
end function
print Gen( 1 )

#print === a multi-line macro earlier in a generic member body ===
#macro PRINT2( e )
	print e
	print e
#endmacro
type Twice( of T )
	v as T
	declare sub Run( )
end type
sub Twice( of T ).Run( )
	PRINT2( v )
	print nothere10
end sub
dim as Twice( of long ) tw
tw.Run( )

#print === done ===
