'' Included by generic-body-lines.bas: a generic in a HEADER, so the quoted
'' line must come from this file, not from the file that includes it.

type Header( of T )
	as T v
	declare sub Fill( )
end type

sub Header( of T ).Fill( )
	dim as T tmp = this.v
	this.v = notdeclaredhere
end sub
