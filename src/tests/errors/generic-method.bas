'' A member procedure with type parameters of its own -- a generic method.
''
'' There are none.  The '( of F )' clause used to be read as the parameter
'' list, a parameter named 'of', and the message was "error 147: Default types
'' or suffixes are only valid in -lang deprecated, found 'F'".  One case per
'' file (see readme.txt); the consequences in the body are not the point.

#print === a generic method on a plain type ===
type Plain
	as long v
	declare sub Visit( of F )( byval f as F )
end type

#print === a parameter named OF is still a parameter ===
type OfParam
	as long v
	declare sub Take( byval of as long )
end type
sub OfParam.Take( byval of as long )
	this.v = of
end sub

#print === done ===
