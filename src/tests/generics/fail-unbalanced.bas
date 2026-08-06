' TEST_MODE : COMPILE_ONLY_FAIL
/'
	The structural pre-scan runs at declaration time: a generic body whose
	blocks do not balance is reported at the generic's own line, without
	waiting for an instantiation.
'/
type Box( of T )
	as T v
'' no 'end type'
