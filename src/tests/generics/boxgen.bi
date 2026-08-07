'' The generic under test.  In a header only so main.bas reads as one story;
'' probe.bas deliberately does NOT include it, and names the methods purely by
'' their mangled strings.

type Box( of T )
	as T v
	declare function take( byval a as T ) as T
end type

function Box( of T ).take( byval a as T ) as T
	this.v = a
	return this.v
end function

'' A generic GLOBAL operator.  Same instantiate-once-per-argument-list path, but
'' a different mangling branch: hMangleProc takes the operator arm for the id, so
'' the type arguments do not appear as an 'I...E' list on the operator itself --
'' they reach the name through the PARAMETER types, which is enough to keep
'' instantiations apart.
operator + ( of T )( byref a as Box( of T ), byref b as Box( of T ) ) as Box( of T )
	dim as Box( of T ) r
	r.v = a.v + b.v
	return r
end operator
