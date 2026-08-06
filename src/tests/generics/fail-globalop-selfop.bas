' TEST_MODE : COMPILE_ONLY_FAIL

'' A self op is always a method, and a GLOBAL operator has no parent type to be
'' a method of.  The way to write this is 'operator Box( of T ).+=', which is an
'' ordinary member body of a generic type and works.
''
'' Reported here rather than left to cProcHeader, because by the time the generic
'' capture path has claimed the statement there is no parent for cProcHeader to
'' complain about.

type Box( of T )
	as T v
end type

operator += ( of T )( byref x as Box( of T ), byref y as Box( of T ) )
	x.v += y.v
end operator
