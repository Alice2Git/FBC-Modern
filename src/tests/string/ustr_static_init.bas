' TEST_MODE : COMPILE_AND_RUN_OK

'' A USTRING * N in static data (SHARED, STATIC, a field of either) can be
'' initialized from a string literal.
''
'' The literal went to the backend through the narrow string emitter: gcc
'' rejected a narrow "..." for the uint16 array, and gas / gas64 packed the
'' bytes two to a code unit, so "abc" read back as two garbage characters.
'' The literal is now converted to UTF-16 at compile time and emitted unit by
'' unit, terminator and zero padding included.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' --------------------------------------------------------- SHARED

dim shared as ustring * 10 ascii = "abc"
dim shared as ustring * 10 empty = ""
'' N counts the terminator, as for WSTRING * N and for a local USTRING * N:
'' "xyz" fits a * 4 exactly and is cut to "xy" in a * 3 (warning 9, as for a
'' local)
dim shared as ustring * 4 full = "xyz"
dim shared as ustring * 3 cut = "xyz"
dim shared as ustring * 10 wide = wstr( "wide" )

'' UTF-8 in the source: two BMP characters and one astral (a surrogate pair)
dim shared as ustring * 10 diacritics = "ăî"
dim shared as ustring * 10 astral = "𝄞"

scope
	assert_( ascii = "abc" )
	assert_( len( ascii ) = 3 )
	assert_( ascii[0] = asc( "a" ) andalso ascii[1] = asc( "b" ) andalso ascii[2] = asc( "c" ) )
	assert_( ascii[3] = 0 )

	assert_( len( empty ) = 0 )

	assert_( full = "xyz" )
	assert_( len( full ) = 3 )

	assert_( cut = "xy" )
	assert_( len( cut ) = 2 )

	assert_( wide = "wide" )

	dim as ustring expect = "ăî"
	assert_( diacritics = expect )
	assert_( len( diacritics ) = 2 )
	assert_( diacritics[0] = &h0103 andalso diacritics[1] = &h00EE )

	assert_( len( astral ) = 2 )
	assert_( astral[0] = &hD834 andalso astral[1] = &hDD1E )
end scope

'' the data is writable and the declared capacity is all there
scope
	ascii = "012345678"
	assert_( ascii = "012345678" )
	assert_( len( ascii ) = 9 )
end scope

'' ------------------------------------------------- STATIC locals

function Counter( ) as ustring
	static as ustring * 8 label = "count"
	static as long n
	n += 1
	return label & n
end function

scope
	assert_( Counter( ) = "count1" )
	assert_( Counter( ) = "count2" )
end scope

'' ------------------------------------- fields of a static UDT and arrays

type Entry
	as long id
	as ustring * 6 name_
	as double weight
end type

dim shared as Entry e1 = ( 7, "seven", 1.5 )
dim shared as ustring * 4 names( 0 to 2 ) = { "one", "two", "six" }

scope
	assert_( e1.id = 7 )
	assert_( e1.name_ = "seven" )
	assert_( e1.weight = 1.5 )

	assert_( names( 0 ) = "one" )
	assert_( names( 1 ) = "two" )
	assert_( names( 2 ) = "six" )
end scope
