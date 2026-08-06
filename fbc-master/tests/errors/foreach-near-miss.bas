'' RFC-0002 7: when GetIterator returns something that is ALMOST an iterator,
'' the diagnostic names the member that is missing.  A bare "not iterable" would
'' be useless -- the failure mode of a structural protocol is getting it nearly
'' right.

#print === the iterator has IsValid and Value but no MoveNext ===
type It
	as long i
	declare function IsValid( ) as boolean
	declare function Value( ) as long
end type

function It.IsValid( ) as boolean
	return this.i < 1
end function

function It.Value( ) as long
	return 1
end function

type C1
	as long unused
	declare function GetIterator( ) as It
end type

function C1.GetIterator( ) as It
	dim r as It
	return r
end function

dim c as C1

for each v in c
next
