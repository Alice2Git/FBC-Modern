' TEST_MODE : COMPILE_AND_RUN_OK

'' -gen gas64: a function returning a UDT of 64 bytes or more crashed when an
'' argument had to be computed first -- another such call's result passed
'' byref, or a float expression like 'x * 0.5'.
''
'' The result's temporary is cleared with memset before the call. Its address
'' sat in r8, which memset needs for the size, so it was moved to another
'' register, but memset still got the old name: after the peephole optimizer
'' merged 'lea r8, tmp' + 'mov r12, r8' into 'lea r12, tmp', r8 held garbage.
'' Below 64 bytes the temporary is cleared inline, without memset.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Big64
	as single m(0 to 15)
end type

type Big88
	as single m(0 to 21)
end type

type Big256
	as double m(0 to 31)
end type

function Make64( byval v as single ) as Big64
	dim as Big64 r
	r.m(0) = v
	r.m(15) = v + 1
	return r
end function

function Make88( byval v as single ) as Big88
	dim as Big88 r
	r.m(0) = v
	r.m(21) = v + 1
	return r
end function

function Make256( byval v as double ) as Big256
	dim as Big256 r
	r.m(0) = v
	r.m(31) = v + 1
	return r
end function

function Add64( byref a as const Big64, byref b as const Big64 ) as Big64
	dim as Big64 r
	for i as integer = 0 to 15
		r.m(i) = a.m(i) + b.m(i)
	next
	return r
end function

function Mul64( byref a as const Big64, byval k as single ) as Big64
	dim as Big64 r
	for i as integer = 0 to 15
		r.m(i) = a.m(i) * k
	next
	return r
end function

'' float expression as the argument
sub test_float_arg( byval x as single )
	dim as Big64 a = Make64( x * 0.5 )
	assert_( a.m(0) = 1.5 )
	assert_( a.m(15) = 2.5 )

	dim as Big88 b = Make88( x + 1 )
	assert_( b.m(0) = 4 )
	assert_( b.m(21) = 5 )

	dim as Big256 c = Make256( x / 2 )
	assert_( c.m(0) = 1.5 )
	assert_( c.m(31) = 2.5 )
end sub

'' another call's result passed byref
sub test_temp_arg( )
	dim as Big64 x = Make64( 1 )
	dim as Big64 y = Add64( x, Make64( 2 ) )
	assert_( y.m(0) = 3 )
	assert_( y.m(15) = 5 )

	dim as Big64 z = Add64( Make64( 10 ), Add64( x, Make64( 2 ) ) )
	assert_( z.m(0) = 13 )
	assert_( z.m(15) = 16 )
end sub

'' both at once, as in 'Mat4Mul( proj, Mat4Mul( view, Mat4RotateX( angle * 0.7 ) ) )'
sub test_nested( byval angle as single )
	dim as Big64 p = Make64( 1 )
	dim as Big64 r = Add64( p, Mul64( Make64( angle * 0.5 ), angle - 2 ) )
	assert_( r.m(0) = 5 )        '' 1 + 2 * 2
	assert_( r.m(15) = 8 )       '' 2 + 3 * 2
end sub

test_float_arg( 3 )
test_temp_arg( )
test_nested( 4 )
