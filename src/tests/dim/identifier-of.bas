' TEST_MODE : FBCUNIT_COMPATIBLE

#include "fbcunit.bi"

'' RFC-0001 promises that adding generics does not make 'of' a reserved word:
''
''     dim of as long = 7 : print of
''
'' compiles today and must keep compiling.  That rules out putting 'of' in the
'' keyword table -- not even as an FB_TKCLASS_QUIRKWD, because a QUIRKWD cannot
'' be used as a variable name (dim len as long and dim screen as long both fail
'' with "Duplicated definition").  'of' is therefore matched purely by token
'' text, in the one position where a type argument list can appear.
''
'' This test exists to catch a regression in that promise, and is deliberately
'' written before any of the (of T) grammar exists.

SUITE( fbc_tests.dim_.identifier_of )

	type of_holder
		of as long          '' as a field name
	end type

	type of                 '' as a type name
		v as long
	end type

	private function of_proc( byval of as long ) as long   '' as a parameter name
		return of * 2
	end function

	TEST( of_as_variable )
		dim of as long = 7
		CU_ASSERT_EQUAL( of, 7 )
		of += 1
		CU_ASSERT_EQUAL( of, 8 )
	END_TEST

	TEST( of_as_field )
		dim h as of_holder
		h.of = 3
		CU_ASSERT_EQUAL( h.of, 3 )
	END_TEST

	TEST( of_as_type )
		dim x as of
		x.v = 5
		CU_ASSERT_EQUAL( x.v, 5 )
	END_TEST

	TEST( of_as_parameter )
		CU_ASSERT_EQUAL( of_proc( 21 ), 42 )
	END_TEST

END_SUITE
