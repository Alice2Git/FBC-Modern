' TEST_MODE : COMPILE_AND_RUN_OK

'' sizeof/len over a generic instantiation.
''
'' These go through cTypeOrExpression, not the cSymbolType path used by 'dim',
'' and that disambiguator rejects a '(' after an identifier -- so without a
'' special case the generic falls through to the expression parser and is
'' reported as an undeclared variable.  A call argument can never begin with
'' 'of', which is what makes the position unambiguous.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Box( of T )
	as T value
end type

	assert_( sizeof( Box( of long ) ) = sizeof( long ) )
	assert_( sizeof( Box( of double ) ) = sizeof( double ) )

	dim b as Box( of long )
	assert_( len( b ) = sizeof( long ) )

	'' the instantiation used by sizeof is the same one 'dim' uses
	dim d as Box( of double )
	assert_( len( d ) = sizeof( Box( of double ) ) )
