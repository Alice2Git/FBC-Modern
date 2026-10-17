' TEST_MODE : COMPILE_AND_RUN_OK

'' CDBL / CSNG / CAST on a CONST DOUBLE or CONST SINGLE.
''
'' With -gen gas64 the result was 0 or garbage: 'cdbl( a )' with a a CONST
'' DOUBLE compiled to
''
''     cvtss2sd xmm0, 0[r11]
''
'' i.e. a single -> double conversion of the first 4 bytes.  The AST marks a
'' change of CONST bits only as a CONV node with doconv = FALSE, and loading it
'' calls irSetVregDataType(); gas64's version sent every type change through
'' _emitconvert, whose float -> float branch assumed a DOUBLE target always
'' meant a SINGLE source.  Now a CONST-only change is a retype, and
'' _emitconvert copies a float to the same float type.
''
'' Reported by TestKit as b02.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

function CdblByref( byref a as const double ) as double
	return cdbl( a )
end function

function CdblByval( byval a as const double ) as double
	return cdbl( a )
end function

function CastByref( byref a as const double ) as double
	return cast( double, a )
end function

function CsngByref( byref a as const single ) as single
	return csng( a )
end function

function CsngByval( byval a as const single ) as single
	return csng( a )
end function

'' real conversions, which must stay conversions
function CdblFromSingle( byref a as const single ) as double
	return cdbl( a )
end function

function CsngFromDouble( byref a as const double ) as single
	return csng( a )
end function

function CdblFromLong( byref a as const long ) as double
	return cdbl( a )
end function

'' integers go through the same retype
function ClngByref( byref a as const long ) as long
	return clng( a )
end function

function ClngintByref( byref a as const longint ) as longint
	return clngint( a )
end function

dim as double d = 0.1      '' not exact as a single
dim as single s = 1.5
dim as long l = -123456
dim as longint ll = &h123456789ABCDEF

assert_( CdblByref( d ) = d )
assert_( CdblByval( d ) = d )
assert_( CastByref( d ) = d )
assert_( CsngByref( s ) = s )
assert_( CsngByval( s ) = s )

assert_( CdblFromSingle( s ) = 1.5 )
assert_( CsngFromDouble( d ) = csng( 0.1 ) )
assert_( CdblFromLong( l ) = -123456 )
assert_( ClngByref( l ) = l )
assert_( ClngintByref( ll ) = ll )

'' CONST locals
scope
	dim as const double cd = d
	dim as const single cs = s
	dim as double r1 = cdbl( cd )
	dim as single r2 = csng( cs )
	dim as double r3 = cdbl( cs )
	assert_( r1 = d )
	assert_( r2 = s )
	assert_( r3 = 1.5 )
end scope

'' in an expression, not only as a result
function Twice( byref a as const double ) as double
	return cdbl( a ) + cdbl( a )
end function

assert_( Twice( d ) = d + d )
