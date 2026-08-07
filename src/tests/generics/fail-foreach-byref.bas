' TEST_MODE : COMPILE_ONLY_FAIL

'' BYREF binding needs the element to have an address, which a user collection
'' provides only when its iterator's Value( ) hands one back.

type It
	as long i
	declare function IsValid( ) as boolean
	declare function Value( ) as long
	declare sub MoveNext( )
end type

function It.IsValid( ) as boolean
	return this.i < 2
end function

function It.Value( ) as long
	return this.i
end function

sub It.MoveNext( )
	this.i += 1
end sub

type C1
	as long unused
	declare function GetIterator( ) as It
end type

function C1.GetIterator( ) as It
	dim r as It
	return r
end function

dim c as C1

for each byref v as long in c
next
