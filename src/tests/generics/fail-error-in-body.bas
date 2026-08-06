' TEST_MODE : COMPILE_ONLY_FAIL
/'
	An error inside a generic body is reported when the generic is instantiated,
	and is followed by the instantiation chain:

	    fail-error-in-body.bas(N) error 14: Expected identifier, found 'Wdiget'
	      in instantiation of 'Box( of long )'
	      required from fail-error-in-body.bas(M)

	This checks only that it fails; the chain TEXT is not asserted anywhere yet
	(the golden error harness does not exist).
'/
type Box( of T )
	as T value
	as Wdiget oops
end type

dim b as Box( of long )
