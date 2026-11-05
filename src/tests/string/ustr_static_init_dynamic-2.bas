' TEST_MODE : COMPILE_ONLY_FAIL

'' A STATIC local dynamic USTRING cannot be initialized either (error 87), as
'' a STATIC dynamic STRING cannot.

sub f( )
	static as ustring s = "x"
end sub
