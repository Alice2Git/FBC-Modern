' TEST_MODE : COMPILE_AND_RUN_OK

'' Distinct instantiations must not collapse onto one another.
''
'' THIS TEST WAS WEAKENED BY PHASE 13, deliberately and with the loss recorded.
''
'' It used to be two modules: probe.bas named each instantiated method by its
'' exact Itanium ALIAS and took its address, so the LINK failed if mangling
'' drifted -- which is how the Phase 5 collapse (four instantiations, one
'' external name) was caught.
''
'' Phase 13 made every generic instantiation MODULE-PRIVATE, because a PE/COFF
'' target has no weak definitions and an instantiation reached from two modules
'' otherwise fails to link at all.  Module-private symbols cannot be named from
'' another module, so the link-time assertion is no longer expressible.
''
'' What survives is the behavioural half, and it still catches a collapse: two
'' instantiations sharing one mangled name would now be two C functions with the
'' same name in one file, which the C compiler rejects outright rather than
'' silently keeping one.  What is LOST is the assertion on the exact NAME -- the
'' mangling could drift to some other distinct scheme and this would not notice.
'' src/tests/generics/multimodule/ covers the linking half instead.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

#include once "boxgen.bi"

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

	'' the generic global operator, on two argument lists
	dim bl2 as Box( of long )
	bl2.v = 5
	dim as Box( of long ) sl = bl + bl2
	assert_( sl.v = 8 )

	dim bd2 as Box( of double )
	bd.v = 0.25 : bd2.v = 0.5
	dim as Box( of double ) sd = bd + bd2
	assert_( sd.v = 0.75 )



	'' A collapse would make two of these the same function.  Each must return
	'' what its OWN element type says.
	assert_( bl.take( 7 ) = 7 )
	assert_( bd.take( 2.5 ) = 2.5 )
	assert_( bl.v = 7 )
	assert_( bd.v = 2.5 )
