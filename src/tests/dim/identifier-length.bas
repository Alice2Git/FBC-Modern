' TEST_MODE : FBCUNIT_COMPATIBLE

#include "fbcunit.bi"

'' Pins the identifier truncation boundary at FB_MAXNAMELEN (128).
''
'' The lexer truncates identifiers longer than FB_MAXNAMELEN, and
'' symbLookup()/symbLookupAt() case-fold into a FB_MAXNAMELEN+1 buffer.
'' Both halves of that contract are checked here, so that changing one
'' without the other is caught:
''
''   - two ids differing only AFTER char 128 must be the SAME symbol
''   - two ids differing BEFORE char 128 must be DISTINCT symbols

SUITE( fbc_tests.dim_.identifier_length )

	TEST( past_boundary_same_symbol )
		'' 128 a's, then differing suffixes: both truncate to the same id
		dim as long aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX = 7
		aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaY = 9
		CU_ASSERT_EQUAL( aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaX, 9 )
	END_TEST

	TEST( before_boundary_distinct_symbols )
		'' 100 b's, then differing suffixes: well under the limit, so distinct
		dim as long bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbX = 7
		dim as long bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbY = 9
		CU_ASSERT_EQUAL( bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbX, 7 )
		CU_ASSERT_EQUAL( bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbY, 9 )
	END_TEST

END_SUITE
