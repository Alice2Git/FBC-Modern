# include "fbcunit.bi"

'' UDT results small enough to come back in registers (linux-x86_64 gas64:
'' up to 16 bytes, in RAX / RDX / XMM0 / XMM1), stored into every kind of
'' destination.  Each case once miscompiled under -gen gas64:
''
'' - a 9..16 byte result stored through a pointer, a BYREF parameter or into
''   an array element crashed the compiler (null symbol), or wrote the second
''   half to the wrong place, or wrote it from a register the address
''   computation had already reused
'' - a 1..8 byte result was stored as a LONGINT / DOUBLE whatever its size,
''   overwriting the bytes after it
'' - a function with several 'return Call( )' statements returned the last
''   call's slot from every one of them
''
'' Nothing here is gas64-specific: the same results must hold on every target
'' and backend.

SUITE( fbc_tests.functions.udt_result_regs )

	type S1 : a as ubyte : end type
	type S2 : a as short : end type
	type S3 : a(0 to 2) as ubyte : end type
	type S4 : a as long : end type
	type S5 : a(0 to 4) as ubyte : end type
	type S6 : a(0 to 2) as short : end type
	type S7 : a(0 to 6) as ubyte : end type
	type S8 : a as long : b as long : end type
	type F4 : f as single : end type
	type F8 : f as single : g as single : end type

	type RR : a as longint : b as short : end type         '' rax:rdx
	type RX : a as longint : d as double : end type        '' rax:xmm0
	type XR : d as double : a as long : end type           '' xmm0:rax
	type XX : d as double : f as single : end type         '' xmm0:xmm1
	type P11 field = 1 : a as longint : c(0 to 2) as ubyte : end type
	type P15 field = 1 : a as longint : c(0 to 6) as ubyte : end type
	type Outer : x as long : r as RR : y as long : end type

	#macro MKBYTES( T, N, ET )
		function Mk##T( byval i as long ) as T
			dim r as T
			for k as long = 0 to N - 1
				r.a(k) = cast( ET, i * 10 + k + 1 )
			next
			return r
		end function
		function Sum##T( byref r as T ) as long
			dim s as long
			for k as long = 0 to N - 1
				s += r.a(k) * (k + 1)
			next
			return s
		end function
	#endmacro
	MKBYTES( S3, 3, ubyte )
	MKBYTES( S5, 5, ubyte )
	MKBYTES( S6, 3, short )
	MKBYTES( S7, 7, ubyte )

	function MkS1( byval i as long ) as S1 : dim r as S1 : r.a = i + 100 : return r : end function
	function MkS2( byval i as long ) as S2 : dim r as S2 : r.a = -i * 300 : return r : end function
	function MkS4( byval i as long ) as S4 : dim r as S4 : r.a = -i * 100000 : return r : end function
	function MkS8( byval i as long ) as S8 : dim r as S8 : r.a = i : r.b = -i * 3 : return r : end function
	function MkF4( byval i as long ) as F4 : dim r as F4 : r.f = i + 0.5 : return r : end function
	function MkF8( byval i as long ) as F8 : dim r as F8 : r.f = i + 0.25 : r.g = -i - 0.75 : return r : end function

	function MkRR( byval i as long ) as RR : dim r as RR : r.a = 1000000000000ll + i : r.b = -i - 1 : return r : end function
	function MkRX( byval i as long ) as RX : dim r as RX : r.a = i * 3 : r.d = i + 0.5 : return r : end function
	function MkXR( byval i as long ) as XR : dim r as XR : r.d = i * 1.25 : r.a = -i * 7 : return r : end function
	function MkXX( byval i as long ) as XX : dim r as XX : r.d = i * 2.5 : r.f = i + 0.25 : return r : end function
	function MkP11( byval i as long ) as P11
		dim r as P11 : r.a = i * 11
		for k as long = 0 to 2 : r.c(k) = i + k + 1 : next
		return r
	end function
	function MkP15( byval i as long ) as P15
		dim r as P15 : r.a = i * 15
		for k as long = 0 to 6 : r.c(k) = i + k + 1 : next
		return r
	end function

	sub StoreByref( byref d as RR, byval i as long )
		d = MkRR( i )
	end sub
	sub StorePtr( byval p as RX ptr, byval i as long )
		*p = MkRX( i )
	end sub

	'' several returns of a call: each must return its own call's result
	function Pick( byval n as long ) as RR
		if n > 10 then return MkRR( 100 )
		if n > 5 then return MkRR( 50 )
		return MkRR( n )
	end function
	function PickS3( byval n as long ) as S3
		if n > 5 then return MkS3( 9 )
		return MkS3( n )
	end function

	dim shared as RR shRR
	dim shared as RR shArr(0 to 3)

	TEST( small_no_overrun )
		const G = &h5A5A5A5A
		dim as long g0 = G
		dim as S1 s1 : dim as long g1 = G
		dim as S2 s2 : dim as long g2 = G
		dim as S3 s3 : dim as long g3 = G
		dim as S4 s4 : dim as long g4 = G
		dim as S5 s5 : dim as long g5 = G
		dim as S6 s6 : dim as long g6 = G
		dim as S7 s7 : dim as long g7 = G
		dim as F4 f4 : dim as long g8 = G

		s1 = MkS1( 1 ) : s2 = MkS2( 2 ) : s3 = MkS3( 3 ) : s4 = MkS4( 4 )
		s5 = MkS5( 5 ) : s6 = MkS6( 6 ) : s7 = MkS7( 7 ) : f4 = MkF4( 8 )

		CU_ASSERT_EQUAL( s1.a, 101 )
		CU_ASSERT_EQUAL( s2.a, -600 )
		CU_ASSERT_EQUAL( SumS3( s3 ), 31 * 1 + 32 * 2 + 33 * 3 )
		CU_ASSERT_EQUAL( s4.a, -400000 )
		CU_ASSERT_EQUAL( SumS5( s5 ), 51 * 1 + 52 * 2 + 53 * 3 + 54 * 4 + 55 * 5 )
		CU_ASSERT_EQUAL( SumS6( s6 ), 61 * 1 + 62 * 2 + 63 * 3 )
		CU_ASSERT_EQUAL( SumS7( s7 ), 71 * 1 + 72 * 2 + 73 * 3 + 74 * 4 + 75 * 5 + 76 * 6 + 77 * 7 )
		CU_ASSERT_EQUAL( f4.f, 8.5 )

		CU_ASSERT_EQUAL( g0, G ) : CU_ASSERT_EQUAL( g1, G ) : CU_ASSERT_EQUAL( g2, G )
		CU_ASSERT_EQUAL( g3, G ) : CU_ASSERT_EQUAL( g4, G ) : CU_ASSERT_EQUAL( g5, G )
		CU_ASSERT_EQUAL( g6, G ) : CU_ASSERT_EQUAL( g7, G ) : CU_ASSERT_EQUAL( g8, G )
	END_TEST

	TEST( small_destinations )
		dim as S3 a3(0 to 3)
		for k as long = 0 to 3
			a3(k) = MkS3( k )
		next
		for k as long = 0 to 3
			CU_ASSERT_EQUAL( SumS3( a3(k) ), (k*10+1) * 1 + (k*10+2) * 2 + (k*10+3) * 3 )
		next

		dim as S7 ptr p7 = new S7[2]
		p7[1] = MkS7( 9 ) : p7[0] = MkS7( 8 )
		CU_ASSERT_EQUAL( SumS7( p7[0] ), 81 * 1 + 82 * 2 + 83 * 3 + 84 * 4 + 85 * 5 + 86 * 6 + 87 * 7 )
		CU_ASSERT_EQUAL( SumS7( p7[1] ), 91 * 1 + 92 * 2 + 93 * 3 + 94 * 4 + 95 * 5 + 96 * 6 + 97 * 7 )
		delete[] p7

		'' used without a named destination
		CU_ASSERT_EQUAL( MkS1( 5 ).a, 105 )
		CU_ASSERT_EQUAL( MkS4( 6 ).a, -600000 )
		CU_ASSERT_EQUAL( MkF4( 7 ).f, 7.5 )
		CU_ASSERT_EQUAL( MkF8( 3 ).f, 3.25 )
		CU_ASSERT_EQUAL( MkF8( 3 ).g, -3.75 )
		CU_ASSERT_EQUAL( MkS8( 5 ).b, -15 )
		CU_ASSERT_EQUAL( MkS6( 2 ).a(2), 23 )
	END_TEST

	TEST( large_destinations )
		static as XR st
		dim as RR l
		dim as RR arr(0 to 3)
		dim as Outer o
		dim as long lo = 111
		dim as XX xs(1 to 4)
		dim as long hi = 222
		dim as long j = 7

		l = MkRR( 1 )
		CU_ASSERT_EQUAL( l.a, 1000000000001ll ) : CU_ASSERT_EQUAL( l.b, -2 )

		StoreByref( l, 2 )
		CU_ASSERT_EQUAL( l.a, 1000000000002ll ) : CU_ASSERT_EQUAL( l.b, -3 )

		dim as RX rx
		StorePtr( @rx, 3 )
		CU_ASSERT_EQUAL( rx.a, 9 ) : CU_ASSERT_EQUAL( rx.d, 3.5 )

		dim as RX ptr hp = new RX
		*hp = MkRX( 4 )
		CU_ASSERT_EQUAL( hp->a, 12 ) : CU_ASSERT_EQUAL( hp->d, 4.5 )
		delete hp

		for k as long = 0 to 3
			arr(k) = MkRR( k + 10 )
		next
		for k as long = 0 to 3
			CU_ASSERT_EQUAL( arr(k).a, 1000000000010ll + k )
			CU_ASSERT_EQUAL( arr(k).b, -k - 11 )
		next

		'' the index is computed after the call, with a division (RDX)
		arr( (j * 3) \ 7 ) = MkRR( 42 )
		CU_ASSERT_EQUAL( arr(3).a, 1000000000042ll ) : CU_ASSERT_EQUAL( arr(3).b, -43 )

		o.x = -5 : o.y = -6
		o.r = MkRR( 50 )
		CU_ASSERT_EQUAL( o.x, -5 ) : CU_ASSERT_EQUAL( o.y, -6 )
		CU_ASSERT_EQUAL( o.r.a, 1000000000050ll ) : CU_ASSERT_EQUAL( o.r.b, -51 )

		shRR = MkRR( 60 )
		CU_ASSERT_EQUAL( shRR.a, 1000000000060ll ) : CU_ASSERT_EQUAL( shRR.b, -61 )
		shArr( j - 5 ) = MkRR( 61 )
		CU_ASSERT_EQUAL( shArr(2).a, 1000000000061ll ) : CU_ASSERT_EQUAL( shArr(2).b, -62 )

		st = MkXR( 70 )
		CU_ASSERT_EQUAL( st.d, 87.5 ) : CU_ASSERT_EQUAL( st.a, -490 )

		for k as long = 1 to 4
			xs(k) = MkXX( k )
		next
		for k as long = 1 to 4
			CU_ASSERT_EQUAL( xs(k).d, k * 2.5 ) : CU_ASSERT_EQUAL( xs(k).f, k + 0.25 )
		next
		CU_ASSERT_EQUAL( lo, 111 ) : CU_ASSERT_EQUAL( hi, 222 )

		'' odd sizes, packed
		dim as P11 p11a(0 to 1)
		p11a(1) = MkP11( 3 )
		CU_ASSERT_EQUAL( p11a(1).a, 33 )
		CU_ASSERT_EQUAL( p11a(1).c(0), 4 ) : CU_ASSERT_EQUAL( p11a(1).c(1), 5 ) : CU_ASSERT_EQUAL( p11a(1).c(2), 6 )
		dim as P15 ptr pp = new P15
		*pp = MkP15( 5 )
		CU_ASSERT_EQUAL( pp->a, 75 )
		for k as long = 0 to 6
			CU_ASSERT_EQUAL( pp->c(k), 6 + k )
		next
		delete pp
	END_TEST

	TEST( several_returns )
		dim as RR r
		r = Pick( 20 ) : CU_ASSERT_EQUAL( r.a, 1000000000100ll ) : CU_ASSERT_EQUAL( r.b, -101 )
		r = Pick( 7 )  : CU_ASSERT_EQUAL( r.a, 1000000000050ll ) : CU_ASSERT_EQUAL( r.b, -51 )
		r = Pick( 2 )  : CU_ASSERT_EQUAL( r.a, 1000000000002ll ) : CU_ASSERT_EQUAL( r.b, -3 )
		CU_ASSERT_EQUAL( Pick( 20 ).a, 1000000000100ll )
		CU_ASSERT_EQUAL( SumS3( PickS3( 8 ) ), 91 * 1 + 92 * 2 + 93 * 3 )
		CU_ASSERT_EQUAL( SumS3( PickS3( 1 ) ), 11 * 1 + 12 * 2 + 13 * 3 )
	END_TEST

END_SUITE
