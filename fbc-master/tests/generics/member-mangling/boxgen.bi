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
