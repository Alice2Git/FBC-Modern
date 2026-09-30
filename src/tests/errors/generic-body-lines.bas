'' Where an error inside a generic body is reported.
''
'' The body is compiled by replaying its captured text.  Every error in it used
'' to report the body's FIRST line, and to quote a line of whatever file the
'' replay had interrupted -- usually line 1 of the main file, which is this
'' comment.  The line and the quote must both be the offending line's own.

#include once "generic-body-lines.bi"

#print === a member body, third line ===
type Cutie( of T )
	as T v
	declare sub Pune( )
end type
sub Cutie( of T ).Pune( )
	dim as T a
	this.v = nimic
end sub
dim c as Cutie( of long )
c.Pune( )

#print === a duplicated member: reported on the member, not on the type ===
type Dup( of T )
	as long stare
	declare function Stare( ) as long
end type
dim d as Dup( of long )

#print === a continued line ===
type Cont( of T )
	as T v
	declare function Get( ) as T
end type
function Cont( of T ).Get( ) as T
	return 1 + _
		nothere
end function
dim ct as Cont( of long )

#print === a generic procedure ===
function Gen( of T )( byval x as T ) as T
	dim as T y = x
	return y + missing
end function
print Gen( of long )( 1 )

#print === a one-line body ===
type One( of T )
	as T v
	declare sub S( )
end type
sub One( of T ).S( ) : dim as T q : q = gone : end sub
dim o as One( of long )

#print === a generic declared in an included header ===
dim hd as Header( of long )

#print === done ===
