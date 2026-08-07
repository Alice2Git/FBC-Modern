' TEST_MODE : COMPILE_ONLY_FAIL

'' RFC-0002 §7: when GetIterator returns something that is ALMOST an iterator,
'' say which member is missing.  A bare "not iterable" here would be useless --
'' the whole point of a structural protocol is that you get it nearly right.

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
