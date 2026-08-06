' TEST_MODE : MULTI_MODULE_TEST

'' Distinct instantiations must get distinct external names for their methods.
''
'' The check lives in probe.bas, which names them as ALIAS strings so the LINK
'' fails if mangling drifts.  Two modules, because a single one cannot do it:
''
''   - matching signatures make fbc report "Duplicated definition" against the
''     real method
''   - non-matching signatures make gcc report a conflicting prototype, since
''     both land in the same generated C file
''
'' Same shape as tests/namespace/cpp-abbrev.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

#include once "boxgen.bi"

declare function probe_addrs( ) as integer

	dim bl as Box( of long )
	dim bd as Box( of double )
	dim bn as Box( of Box( of long ) )

	assert_( bl.take( 3 ) = 3 )
	assert_( bd.take( 0.5 ) = 0.5 )

	'' Box( of Box( of long ) ) really nests: take() moves a whole
	'' Box( of long ) through, which only type-checks if the two are
	'' distinct types
	dim inner as Box( of long )
	inner.v = 8
	assert_( bn.take( inner ).v = 8 )
	assert_( bn.v.v = 8 )

	'' resolving the ALIAS names is the actual test; this just makes sure the
	'' other module is linked in and reached
	assert_( probe_addrs( ) = 3 )
