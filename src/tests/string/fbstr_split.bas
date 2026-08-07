'' FB.Split / SplitChars / Join -- exhaustive.
''
'' The only functions in this library with FreeBASIC bodies rather than
'' declarations, because their result is an Array( of T ). Three things need
'' pinning that no earlier phase could:
''
''   1. THE FIELD COUNT IS ALWAYS AT LEAST 1, and N delimiters give N+1 fields.
''      Empty fields at either end and in the middle are real fields, never
''      dropped. Every off-by-one in a split shows up here.
''
''   2. Join( Split( s, d ), d ) = s FOR EVERY s. That round trip is the whole
''      reason the empty-field rule is what it is, so it is asserted as a
''      property over a table of awkward inputs rather than as a few cases.
''
''   3. THE PRIVATE-BODY LINKAGE. These are `private` so that two modules
''      including the header still link. tests/string/fbstr_split_mod2.bas
''      includes it as well and is linked into the same binary; if the private
''      were dropped, the suite would fail to link rather than fail an
''      assertion.

#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

'' defined in fbstr_split_mod2.bas -- proves two modules can both include the
'' header, which is the whole point of the bodies being private
declare function SplitInOtherModule( byref s as const string ) as integer

SUITE( fbc_tests.string_.fbstr_split )

	'' ------------------------------------------------------------ Split

	TEST( split_string_basics )
		dim a as Array( of string ) = Split( "a,b,c" )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[0], "a" )
		CU_ASSERT_EQUAL( a[1], "b" )
		CU_ASSERT_EQUAL( a[2], "c" )

		'' the default delimiter is a comma
		dim b as Array( of string ) = Split( "x;y", ";" )
		CU_ASSERT_EQUAL( b.Count( ), 2 )
		CU_ASSERT_EQUAL( b[0], "x" )
		CU_ASSERT_EQUAL( b[1], "y" )

		'' multi-character delimiter
		dim c as Array( of string ) = Split( "a<>b<>c", "<>" )
		CU_ASSERT_EQUAL( c.Count( ), 3 )
		CU_ASSERT_EQUAL( c[1], "b" )
	END_TEST

	TEST( split_empty_fields_are_fields )
		'' N delimiters -> N+1 fields, ALWAYS. Nothing is dropped.
		dim a as Array( of string ) = Split( "a,,c" )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[1], "" )

		dim b as Array( of string ) = Split( ",a" )
		CU_ASSERT_EQUAL( b.Count( ), 2 )
		CU_ASSERT_EQUAL( b[0], "" )
		CU_ASSERT_EQUAL( b[1], "a" )

		dim c as Array( of string ) = Split( "a," )
		CU_ASSERT_EQUAL( c.Count( ), 2 )
		CU_ASSERT_EQUAL( c[0], "a" )
		CU_ASSERT_EQUAL( c[1], "" )

		dim d as Array( of string ) = Split( "," )
		CU_ASSERT_EQUAL( d.Count( ), 2 )
		CU_ASSERT_EQUAL( d[0], "" )
		CU_ASSERT_EQUAL( d[1], "" )

		dim e as Array( of string ) = Split( ",,," )
		CU_ASSERT_EQUAL( e.Count( ), 4 )

		'' an empty string is ONE empty field, not zero fields
		dim f as Array( of string ) = Split( "" )
		CU_ASSERT_EQUAL( f.Count( ), 1 )
		CU_ASSERT_EQUAL( f[0], "" )

		'' no delimiter present is one field, the whole string
		dim g as Array( of string ) = Split( "abc" )
		CU_ASSERT_EQUAL( g.Count( ), 1 )
		CU_ASSERT_EQUAL( g[0], "abc" )

		'' an EMPTY delimiter splits nothing
		dim h as Array( of string ) = Split( "abc", "" )
		CU_ASSERT_EQUAL( h.Count( ), 1 )
		CU_ASSERT_EQUAL( h[0], "abc" )

		'' the delimiter is the whole string
		dim i_ as Array( of string ) = Split( "abc", "abc" )
		CU_ASSERT_EQUAL( i_.Count( ), 2 )
		CU_ASSERT_EQUAL( i_[0], "" )
		CU_ASSERT_EQUAL( i_[1], "" )

		'' a delimiter longer than the input cannot match
		dim j as Array( of string ) = Split( "ab", "abcd" )
		CU_ASSERT_EQUAL( j.Count( ), 1 )
	END_TEST

	TEST( split_non_overlapping_and_case )
		'' non-overlapping, matching Tally and Replace
		dim a as Array( of string ) = Split( "aaaa", "aa" )
		CU_ASSERT_EQUAL( a.Count( ), 3 )

		dim b as Array( of string ) = Split( "aaa", "aa" )
		CU_ASSERT_EQUAL( b.Count( ), 2 )
		CU_ASSERT_EQUAL( b[1], "a" )

		dim c as Array( of string ) = Split( "aXbXc", "x" )
		CU_ASSERT_EQUAL( c.Count( ), 1 )

		dim d as Array( of string ) = Split( "aXbXc", "x", true )
		CU_ASSERT_EQUAL( d.Count( ), 3 )
		CU_ASSERT_EQUAL( d[1], "b" )
	END_TEST

	TEST( splitchars_string )
		dim a as Array( of string ) = SplitChars( "a,b;c", ",;" )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[0], "a" )
		CU_ASSERT_EQUAL( a[1], "b" )
		CU_ASSERT_EQUAL( a[2], "c" )

		'' adjacent separators leave an empty field between them
		dim b as Array( of string ) = SplitChars( "a,;b", ",;" )
		CU_ASSERT_EQUAL( b.Count( ), 3 )
		CU_ASSERT_EQUAL( b[1], "" )

		dim c as Array( of string ) = SplitChars( "abc", "" )
		CU_ASSERT_EQUAL( c.Count( ), 1 )

		dim d as Array( of string ) = SplitChars( "", ",;" )
		CU_ASSERT_EQUAL( d.Count( ), 1 )

		dim e as Array( of string ) = SplitChars( "aXbYc", "xy", true )
		CU_ASSERT_EQUAL( e.Count( ), 3 )

		'' whitespace tokenising, the common use
		dim f as Array( of string ) = SplitChars( "one two" & chr(9) & "three", " " & chr(9) )
		CU_ASSERT_EQUAL( f.Count( ), 3 )
		CU_ASSERT_EQUAL( f[2], "three" )
	END_TEST

	'' ------------------------------------------------------------- Join

	TEST( join_string )
		dim a as Array( of string )
		CU_ASSERT_EQUAL( Join( a ), "" )              '' empty array

		dim as string one = "solo"
		a.Push( one )
		CU_ASSERT_EQUAL( Join( a ), "solo" )          '' no separator added
		CU_ASSERT_EQUAL( Join( a, "---" ), "solo" )

		dim as string two = "b"
		a.Push( two )
		CU_ASSERT_EQUAL( Join( a ), "solo,b" )
		CU_ASSERT_EQUAL( Join( a, "" ), "solob" )     '' empty delimiter
		CU_ASSERT_EQUAL( Join( a, " -> " ), "solo -> b" )

		'' empty elements are real elements
		dim b as Array( of string )
		dim as string e = ""
		b.Push( e ) : b.Push( e ) : b.Push( e )
		CU_ASSERT_EQUAL( b.Count( ), 3 )
		CU_ASSERT_EQUAL( Join( b ), ",," )
		CU_ASSERT_EQUAL( Join( b, "" ), "" )
	END_TEST

	TEST( join_split_roundtrip )
		'' THE PROPERTY: Join( Split( s, d ), d ) = s, for every s.
		'' This is what the "empty fields are fields" rule buys, so it is
		'' checked over the inputs most likely to break it.
		dim as string cases( 0 to 13 ) = { _
			"", "a", "a,b", "a,b,c", ",", ",,", "a,", ",a", "a,,b", _
			",,a,,", "abc", "a,b,,c,", ",,,,", "one,two,three" }

		for i as integer = 0 to ubound( cases )
			dim parts as Array( of string ) = Split( cases( i ), "," )
			CU_ASSERT_EQUAL( Join( parts, "," ), cases( i ) )
			'' and the field count is the delimiter count plus one
			CU_ASSERT_EQUAL( parts.Count( ), Tally( cases( i ), "," ) + 1 )
		next

		'' the same with a multi-character delimiter
		dim as string mcases( 0 to 4 ) = { "", "a", "a<>b", "<>", "a<><>b" }
		for i as integer = 0 to ubound( mcases )
			dim parts as Array( of string ) = Split( mcases( i ), "<>" )
			CU_ASSERT_EQUAL( Join( parts, "<>" ), mcases( i ) )
		next
	END_TEST

	'' ==================================================================
	'' THE OTHER TYPES
	'' ==================================================================

	TEST( split_zstring )
		'' served by the STRING overload
		dim as zstring * 16 z = "a,b,c"
		dim a as Array( of string ) = Split( z )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[2], "c" )
		CU_ASSERT_EQUAL( Join( a ), "a,b,c" )
	END_TEST

	TEST( split_ustring )
		dim as ustring u = "a,b,c"
		dim a as Array( of ustring ) = Split( u )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[0], "a" )
		CU_ASSERT_EQUAL( a[2], "c" )
		CU_ASSERT_EQUAL( len( a[0] ), 1 )
		CU_ASSERT_EQUAL( Join( a ), "a,b,c" )
		CU_ASSERT_EQUAL( Join( a, "|" ), "a|b|c" )

		dim as ustring ue = ""
		dim b as Array( of ustring ) = Split( ue )
		CU_ASSERT_EQUAL( b.Count( ), 1 )
		CU_ASSERT_EQUAL( b[0], "" )

		dim as ustring * 16 uf = "x;y"
		dim c as Array( of ustring ) = Split( uf, ";" )
		CU_ASSERT_EQUAL( c.Count( ), 2 )
		CU_ASSERT_EQUAL( c[1], "y" )

		dim d as Array( of ustring ) = SplitChars( u, "," )
		CU_ASSERT_EQUAL( d.Count( ), 3 )
	END_TEST

	TEST( split_wstring_gives_ustring_array )
		'' A WSTRING yields an Array( of ustring ), following the same return
		'' rule as every other function here. Binding the result to that type
		'' is what proves it.
		dim as wstring * 16 w = "a,b,c"
		dim a as Array( of ustring ) = Split( w )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( a[1], "b" )
		CU_ASSERT_EQUAL( len( a[1] ), 1 )
		CU_ASSERT_EQUAL( Join( a ), "a,b,c" )

		dim b as Array( of ustring ) = SplitChars( w, "," )
		CU_ASSERT_EQUAL( b.Count( ), 3 )
	END_TEST

	TEST( split_unicode )
		'' Fields are sliced by CODE UNIT on the wide family, so an astral
		'' character inside a field survives whole -- a surrogate half can
		'' never equal a delimiter unit, so a split cannot land mid-character.
		dim as ustring astral = "𝄞"
		CU_ASSERT_EQUAL( len( astral ), 2 )

		dim as ustring u = "a,"
		u &= astral
		u &= ",b"
		CU_ASSERT_EQUAL( len( u ), 6 )

		dim a as Array( of ustring ) = Split( u )
		CU_ASSERT_EQUAL( a.Count( ), 3 )
		CU_ASSERT_EQUAL( len( a[1] ), 2 )
		CU_ASSERT_EQUAL( a[1], astral )
		CU_ASSERT_EQUAL( Join( a ), u )

		'' an astral DELIMITER is two units and still matches as a unit
		dim as ustring v = "x"
		v &= astral
		v &= "y"
		dim b as Array( of ustring ) = Split( v, astral )
		CU_ASSERT_EQUAL( b.Count( ), 2 )
		CU_ASSERT_EQUAL( b[0], "x" )
		CU_ASSERT_EQUAL( b[1], "y" )

		'' accented text, and folding
		dim as ustring acc = "caf" & wchr( &hE9 ) & "X" & wchr( &hE9 )
		dim c as Array( of ustring ) = Split( acc, wchr( &hC9 ), true )
		CU_ASSERT_EQUAL( c.Count( ), 3 )
		CU_ASSERT_EQUAL( c[0], "caf" )
		CU_ASSERT_EQUAL( c[1], "X" )

		'' the byte family splits on BYTES: a UTF-8 field keeps its bytes
		dim as string sb = "caf" & chr( &hC3 ) & chr( &hA9 ) & ",x"
		dim d as Array( of string ) = Split( sb )
		CU_ASSERT_EQUAL( d.Count( ), 2 )
		CU_ASSERT_EQUAL( len( d[0] ), 5 )
		CU_ASSERT_EQUAL( Join( d ), sb )
	END_TEST

	TEST( split_roundtrip_ustring )
		dim as ustring ucases( 0 to 6 )
		ucases( 0 ) = ""
		ucases( 1 ) = "a"
		ucases( 2 ) = "a,b"
		ucases( 3 ) = ","
		ucases( 4 ) = ",,"
		ucases( 5 ) = "a,,b,"
		ucases( 6 ) = "caf" & wchr( &hE9 ) & ",x"

		for i as integer = 0 to ubound( ucases )
			dim parts as Array( of ustring ) = Split( ucases( i ), "," )
			CU_ASSERT_EQUAL( Join( parts, "," ), ucases( i ) )
			CU_ASSERT_EQUAL( parts.Count( ), Tally( ucases( i ), "," ) + 1 )
		next
	END_TEST

	'' ------------------------------------------------- for each / scale

	TEST( split_result_is_a_real_array )
		'' The result is an ordinary FB.Array, so everything that works on one
		'' works here -- including FOR EACH, which is the point of returning a
		'' container rather than a count and an accessor.
		dim a as Array( of string ) = Split( "one,two,three" )

		dim as integer n = 0
		dim as integer chars = 0
		for each p as string in a
			n += 1
			chars += len( p )
		next
		CU_ASSERT_EQUAL( n, 3 )
		CU_ASSERT_EQUAL( chars, 11 )

		'' and it is a value: mutating it does not disturb a fresh split
		a[0] = "CHANGED"
		CU_ASSERT_EQUAL( a[0], "CHANGED" )
		dim b as Array( of string ) = Split( "one,two,three" )
		CU_ASSERT_EQUAL( b[0], "one" )
	END_TEST

	TEST( split_many_fields )
		'' Enough fields that a per-field rescan would be visibly quadratic,
		'' and enough to catch an off-by-one in the two-pass sizing.
		dim as string src = ""
		for i as integer = 1 to 2000
			if i > 1 then src &= ","
			src &= "f"
		next
		CU_ASSERT_EQUAL( Tally( src, "," ), 1999 )

		dim a as Array( of string ) = Split( src )
		CU_ASSERT_EQUAL( a.Count( ), 2000 )
		CU_ASSERT_EQUAL( a[0], "f" )
		CU_ASSERT_EQUAL( a[1999], "f" )
		CU_ASSERT_EQUAL( Join( a, "," ), src )

		'' all-empty fields at scale
		dim as string commas = Repeat( 2000, "," )
		dim b as Array( of string ) = Split( commas )
		CU_ASSERT_EQUAL( b.Count( ), 2001 )
		CU_ASSERT_EQUAL( Join( b, "," ), commas )
	END_TEST

	TEST( split_bodies_are_private_across_modules )
		'' If the bodies were not `private`, this binary would not have
		'' linked at all: the other module includes the same header.
		CU_ASSERT_EQUAL( SplitInOtherModule( "a,b,c,d" ), 4 )
		CU_ASSERT_EQUAL( SplitInOtherModule( "" ), 1 )
	END_TEST

END_SUITE
