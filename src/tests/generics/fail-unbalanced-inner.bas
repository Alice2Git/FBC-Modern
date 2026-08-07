' TEST_MODE : COMPILE_ONLY_FAIL
/'
	An inner block left open: the generic's own 'end type' closes the union,
	so the body never balances.
'/
type Box( of T )
	union
		as T a
		as integer b
end type
