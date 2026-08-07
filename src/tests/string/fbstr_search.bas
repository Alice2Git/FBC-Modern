'' FB.* search and inspect -- exhaustive.
''
'' Eight functions x four argument types x the full edge matrix: empty input,
'' empty needle, no match, match at position 1, match at the last position,
'' adjacent and overlapping matches, needle longer than haystack, ignoreCase
'' both ways, start before / at / past the end, and non-ASCII.
''
'' The four types are STRING, ZSTRING, WSTRING and USTRING. Only three overloads
'' exist -- ZSTRING is served by the STRING one through fbc's implicit
'' conversion -- so the ZSTRING cases are here specifically to prove that
'' conversion picks the right overload and gives the same answers, which is the
'' thing a three-overload set could plausibly get wrong.
''
'' The empty-argument rules are asserted rather than assumed, because each one
'' has a defensible opposite and the choice only exists in one place:
''
''   Tally( s, "" )         = 0     a zero-width match advances nothing
''   InstrChars( n, s, "" ) = 0     "find one of nothing" cannot succeed
''   VerifySet( n, s, "" )  = n     "find one NOT among nothing" cannot fail
''   SpanOf( n, s, "" )     = 0     nothing is in the set, so the run is empty
''   StartsWith( s, "" )    = true  vacuous truth, including for s = ""
''   Contains( s, "" )      = true  same
''
'' Occurrences are NON-OVERLAPPING throughout: "aaaa" contains "aa" twice.

#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

SUITE( fbc_tests.string_.fbstr_search )

	'' ------------------------------------------------------------ Tally

	TEST( tally_string )
		CU_ASSERT_EQUAL( Tally( "", "x" ), 0 )
		CU_ASSERT_EQUAL( Tally( "", "" ), 0 )
		CU_ASSERT_EQUAL( Tally( "abc", "" ), 0 )
		CU_ASSERT_EQUAL( Tally( "abc", "abc" ), 1 )
		CU_ASSERT_EQUAL( Tally( "abc", "abcd" ), 0 )       '' needle longer
		CU_ASSERT_EQUAL( Tally( "aaa", "a" ), 3 )
		CU_ASSERT_EQUAL( Tally( "abcabc", "abc" ), 2 )
		CU_ASSERT_EQUAL( Tally( "xax", "a" ), 1 )          '' interior
		CU_ASSERT_EQUAL( Tally( "abc", "a" ), 1 )          '' at position 1
		CU_ASSERT_EQUAL( Tally( "abc", "c" ), 1 )          '' at the last

		'' non-overlapping, stated loudly
		CU_ASSERT_EQUAL( Tally( "aaaa", "aa" ), 2 )
		CU_ASSERT_EQUAL( Tally( "aaa", "aa" ), 1 )
		CU_ASSERT_EQUAL( Tally( "aaaaa", "aa" ), 2 )

		'' case
		CU_ASSERT_EQUAL( Tally( "ABC", "abc" ), 0 )
		CU_ASSERT_EQUAL( Tally( "ABC", "abc", true ), 1 )
		CU_ASSERT_EQUAL( Tally( "aBcAbC", "abc", true ), 2 )
	END_TEST

	TEST( tally_zstring )
		'' served by the STRING overload -- same answers, or the implicit
		'' conversion picked the wrong one
		dim as zstring * 8 z = "abcabc"
		dim as zstring * 8 n = "abc"
		CU_ASSERT_EQUAL( Tally( z, n ), 2 )
		CU_ASSERT_EQUAL( Tally( z, "bc" ), 2 )
		CU_ASSERT_EQUAL( Tally( z, "" ), 0 )

		dim as zstring * 4 e = ""
		CU_ASSERT_EQUAL( Tally( e, "a" ), 0 )
	END_TEST

	TEST( tally_wstring )
		dim as wstring * 16 w = "abcabc"
		CU_ASSERT_EQUAL( Tally( w, "abc" ), 2 )
		CU_ASSERT_EQUAL( Tally( w, "" ), 0 )
		CU_ASSERT_EQUAL( Tally( w, "ABC", true ), 2 )
		CU_ASSERT_EQUAL( Tally( w, "ABC" ), 0 )

		dim as wstring * 4 we = ""
		CU_ASSERT_EQUAL( Tally( we, "a" ), 0 )
	END_TEST

	TEST( tally_ustring )
		dim as ustring u = "abcabc"
		CU_ASSERT_EQUAL( Tally( u, "abc" ), 2 )
		CU_ASSERT_EQUAL( Tally( u, "" ), 0 )
		CU_ASSERT_EQUAL( Tally( u, "ABC", true ), 2 )

		dim as ustring ue = ""
		CU_ASSERT_EQUAL( Tally( ue, "a" ), 0 )
		CU_ASSERT_EQUAL( Tally( ue, "" ), 0 )

		'' fixed-length form -- a compiler-built temp descriptor, not the
		'' caller's own, which is the form most likely to be unpacked wrong
		dim as ustring * 8 uf = "abcabc"
		CU_ASSERT_EQUAL( Tally( uf, "abc" ), 2 )
	END_TEST

	'' ------------------------------------------------------- TallyChars

	TEST( tallychars_string )
		CU_ASSERT_EQUAL( TallyChars( "hello world", "lo" ), 5 )
		CU_ASSERT_EQUAL( TallyChars( "", "abc" ), 0 )
		CU_ASSERT_EQUAL( TallyChars( "abc", "" ), 0 )
		CU_ASSERT_EQUAL( TallyChars( "abc", "xyz" ), 0 )
		CU_ASSERT_EQUAL( TallyChars( "abc", "abc" ), 3 )
		CU_ASSERT_EQUAL( TallyChars( "aaa", "a" ), 3 )
		CU_ASSERT_EQUAL( TallyChars( "ABC", "abc" ), 0 )
		CU_ASSERT_EQUAL( TallyChars( "ABC", "abc", true ), 3 )
		CU_ASSERT_EQUAL( TallyChars( "aBc", "B" ), 1 )
	END_TEST

	TEST( tallychars_othertypes )
		dim as zstring * 16 z = "hello world"
		dim as wstring * 16 w = "hello world"
		dim as ustring      u = "hello world"
		CU_ASSERT_EQUAL( TallyChars( z, "lo" ), 5 )
		CU_ASSERT_EQUAL( TallyChars( w, "lo" ), 5 )
		CU_ASSERT_EQUAL( TallyChars( u, "lo" ), 5 )
		CU_ASSERT_EQUAL( TallyChars( w, "LO", true ), 5 )
		CU_ASSERT_EQUAL( TallyChars( u, "LO", true ), 5 )
	END_TEST

	'' ------------------------------------------------------- InstrChars

	TEST( instrchars_string )
		CU_ASSERT_EQUAL( InstrChars( 1, "hello", "lo" ), 3 )
		CU_ASSERT_EQUAL( InstrChars( 4, "hello", "lo" ), 4 )   '' resume
		CU_ASSERT_EQUAL( InstrChars( 5, "hello", "lo" ), 5 )   '' last position
		CU_ASSERT_EQUAL( InstrChars( 1, "abc", "a" ), 1 )      '' first position
		CU_ASSERT_EQUAL( InstrChars( 1, "abc", "xyz" ), 0 )    '' no match
		CU_ASSERT_EQUAL( InstrChars( 1, "abc", "" ), 0 )       '' empty set
		CU_ASSERT_EQUAL( InstrChars( 1, "", "abc" ), 0 )       '' empty input
		CU_ASSERT_EQUAL( InstrChars( 0, "abc", "a" ), 0 )      '' start < 1
		CU_ASSERT_EQUAL( InstrChars( -5, "abc", "a" ), 0 )
		CU_ASSERT_EQUAL( InstrChars( 4, "abc", "a" ), 0 )      '' start past end
		CU_ASSERT_EQUAL( InstrChars( 99, "abc", "a" ), 0 )
		CU_ASSERT_EQUAL( InstrChars( 1, "ABC", "a" ), 0 )
		CU_ASSERT_EQUAL( InstrChars( 1, "ABC", "a", true ), 1 )
	END_TEST

	TEST( instrchars_othertypes )
		dim as zstring * 8 z = "hello"
		dim as wstring * 8 w = "hello"
		dim as ustring     u = "hello"
		CU_ASSERT_EQUAL( InstrChars( 1, z, "lo" ), 3 )
		CU_ASSERT_EQUAL( InstrChars( 1, w, "lo" ), 3 )
		CU_ASSERT_EQUAL( InstrChars( 1, u, "lo" ), 3 )
		CU_ASSERT_EQUAL( InstrChars( 0, w, "lo" ), 0 )
		CU_ASSERT_EQUAL( InstrChars( 0, u, "lo" ), 0 )
		CU_ASSERT_EQUAL( InstrChars( 1, w, "LO", true ), 3 )
		CU_ASSERT_EQUAL( InstrChars( 1, u, "LO", true ), 3 )
	END_TEST

	'' -------------------------------------------------------- VerifySet

	TEST( verifyset_string )
		CU_ASSERT_EQUAL( VerifySet( 1, "123a", "0123456789" ), 4 )
		CU_ASSERT_EQUAL( VerifySet( 1, "1234", "0123456789" ), 0 )  '' all in set
		CU_ASSERT_EQUAL( VerifySet( 1, "a123", "0123456789" ), 1 )  '' first fails
		CU_ASSERT_EQUAL( VerifySet( 2, "1a2", "0123456789" ), 2 )
		CU_ASSERT_EQUAL( VerifySet( 3, "1a2", "0123456789" ), 0 )
		CU_ASSERT_EQUAL( VerifySet( 1, "", "0123" ), 0 )            '' empty input
		CU_ASSERT_EQUAL( VerifySet( 1, "abc", "" ), 1 )             '' empty set
		CU_ASSERT_EQUAL( VerifySet( 2, "abc", "" ), 2 )
		CU_ASSERT_EQUAL( VerifySet( 0, "abc", "x" ), 0 )            '' start < 1
		CU_ASSERT_EQUAL( VerifySet( 4, "abc", "x" ), 0 )            '' start past end
		CU_ASSERT_EQUAL( VerifySet( 1, "ABC", "abc" ), 1 )
		CU_ASSERT_EQUAL( VerifySet( 1, "ABC", "abc", true ), 0 )
	END_TEST

	TEST( verifyset_othertypes )
		dim as zstring * 8 z = "123a"
		dim as wstring * 8 w = "123a"
		dim as ustring     u = "123a"
		CU_ASSERT_EQUAL( VerifySet( 1, z, "0123456789" ), 4 )
		CU_ASSERT_EQUAL( VerifySet( 1, w, "0123456789" ), 4 )
		CU_ASSERT_EQUAL( VerifySet( 1, u, "0123456789" ), 4 )
		CU_ASSERT_EQUAL( VerifySet( 1, w, "" ), 1 )
		CU_ASSERT_EQUAL( VerifySet( 1, u, "" ), 1 )
		CU_ASSERT_EQUAL( VerifySet( 0, w, "x" ), 0 )
		CU_ASSERT_EQUAL( VerifySet( 0, u, "x" ), 0 )
	END_TEST

	'' ----------------------------------------------------------- SpanOf

	TEST( spanof_string )
		CU_ASSERT_EQUAL( SpanOf( 1, "   x", " " ), 3 )
		CU_ASSERT_EQUAL( SpanOf( 1, "x  ", " " ), 0 )       '' first not in set
		CU_ASSERT_EQUAL( SpanOf( 1, "   ", " " ), 3 )       '' all in set
		CU_ASSERT_EQUAL( SpanOf( 2, "aab", "a" ), 1 )
		CU_ASSERT_EQUAL( SpanOf( 3, "aab", "a" ), 0 )
		CU_ASSERT_EQUAL( SpanOf( 1, "", "x" ), 0 )          '' empty input
		CU_ASSERT_EQUAL( SpanOf( 1, "abc", "" ), 0 )        '' empty set
		CU_ASSERT_EQUAL( SpanOf( 0, "aa", "a" ), 0 )        '' start < 1
		CU_ASSERT_EQUAL( SpanOf( 5, "aa", "a" ), 0 )        '' start past end
		CU_ASSERT_EQUAL( SpanOf( 1, "AAb", "a" ), 0 )
		CU_ASSERT_EQUAL( SpanOf( 1, "AAb", "a", true ), 2 )
	END_TEST

	TEST( spanof_othertypes )
		dim as zstring * 8 z = "   x"
		dim as wstring * 8 w = "   x"
		dim as ustring     u = "   x"
		CU_ASSERT_EQUAL( SpanOf( 1, z, " " ), 3 )
		CU_ASSERT_EQUAL( SpanOf( 1, w, " " ), 3 )
		CU_ASSERT_EQUAL( SpanOf( 1, u, " " ), 3 )
		CU_ASSERT_EQUAL( SpanOf( 0, w, " " ), 0 )
		CU_ASSERT_EQUAL( SpanOf( 0, u, " " ), 0 )
	END_TEST

	'' ------------------------------------------- StartsWith / EndsWith

	TEST( startswith_string )
		CU_ASSERT( StartsWith( "hello", "he" ) )
		CU_ASSERT( StartsWith( "hello", "hello" ) )     '' whole string
		CU_ASSERT( StartsWith( "hello", "" ) )          '' vacuous
		CU_ASSERT( StartsWith( "", "" ) )               '' vacuous, empty input
		CU_ASSERT( StartsWith( "hello", "HE", true ) )
		CU_ASSERT_EQUAL( StartsWith( "hello", "HE" ), false )
		CU_ASSERT_EQUAL( StartsWith( "hello", "ello" ), false )
		CU_ASSERT_EQUAL( StartsWith( "he", "hello" ), false )   '' prefix longer
		CU_ASSERT_EQUAL( StartsWith( "", "x" ), false )
	END_TEST

	TEST( endswith_string )
		CU_ASSERT( EndsWith( "hello", "lo" ) )
		CU_ASSERT( EndsWith( "hello", "hello" ) )
		CU_ASSERT( EndsWith( "hello", "" ) )
		CU_ASSERT( EndsWith( "", "" ) )
		CU_ASSERT( EndsWith( "hello", "LO", true ) )
		CU_ASSERT_EQUAL( EndsWith( "hello", "LO" ), false )
		CU_ASSERT_EQUAL( EndsWith( "hello", "hell" ), false )
		CU_ASSERT_EQUAL( EndsWith( "lo", "hello" ), false )
		CU_ASSERT_EQUAL( EndsWith( "", "x" ), false )
	END_TEST

	TEST( affixes_othertypes )
		dim as zstring * 8 z = "hello"
		dim as wstring * 8 w = "hello"
		dim as ustring     u = "hello"
		CU_ASSERT( StartsWith( z, "he" ) )
		CU_ASSERT( StartsWith( w, "he" ) )
		CU_ASSERT( StartsWith( u, "he" ) )
		CU_ASSERT( EndsWith( z, "lo" ) )
		CU_ASSERT( EndsWith( w, "lo" ) )
		CU_ASSERT( EndsWith( u, "lo" ) )
		CU_ASSERT( StartsWith( w, "" ) )
		CU_ASSERT( StartsWith( u, "" ) )
		CU_ASSERT( EndsWith( w, "HE" ) = false )
		CU_ASSERT( EndsWith( u, "HE" ) = false )
		CU_ASSERT( StartsWith( w, "HE", true ) )
		CU_ASSERT( StartsWith( u, "HE", true ) )
	END_TEST

	'' --------------------------------------------------------- Contains

	TEST( contains_string )
		CU_ASSERT( Contains( "hello", "ell" ) )
		CU_ASSERT( Contains( "hello", "h" ) )
		CU_ASSERT( Contains( "hello", "o" ) )
		CU_ASSERT( Contains( "hello", "hello" ) )
		CU_ASSERT( Contains( "hello", "" ) )      '' vacuous
		CU_ASSERT( Contains( "", "" ) )
		CU_ASSERT( Contains( "hello", "ELL", true ) )
		CU_ASSERT_EQUAL( Contains( "hello", "ELL" ), false )
		CU_ASSERT_EQUAL( Contains( "hello", "xyz" ), false )
		CU_ASSERT_EQUAL( Contains( "he", "hello" ), false )
		CU_ASSERT_EQUAL( Contains( "", "x" ), false )
	END_TEST

	TEST( contains_othertypes )
		dim as zstring * 8 z = "hello"
		dim as wstring * 8 w = "hello"
		dim as ustring     u = "hello"
		CU_ASSERT( Contains( z, "ell" ) )
		CU_ASSERT( Contains( w, "ell" ) )
		CU_ASSERT( Contains( u, "ell" ) )
		CU_ASSERT( Contains( w, "" ) )
		CU_ASSERT( Contains( u, "" ) )
		CU_ASSERT( Contains( w, "ELL", true ) )
		CU_ASSERT( Contains( u, "ELL", true ) )
		CU_ASSERT( Contains( u, "xyz" ) = false )
	END_TEST

	'' -------------------------------------------------- non-ASCII, wide
	''
	'' The byte family folds ASCII only -- a STRING has no declared encoding.
	'' The wide family folds through the generated simple BMP table, so an
	'' accented character folds and gives the same answer in every locale.

	TEST( unicode_bmp_fold )
		dim as ustring lower = "caf" & wchr( &hE9 )      '' cafe-acute
		dim as ustring upper = "CAF" & wchr( &hC9 )

		CU_ASSERT_EQUAL( len( lower ), 4 )
		CU_ASSERT( Contains( lower, wchr( &hE9 ) ) )
		CU_ASSERT_EQUAL( Contains( lower, wchr( &hC9 ) ), false )
		CU_ASSERT( Contains( lower, wchr( &hC9 ), true ) )      '' folds
		CU_ASSERT( EndsWith( lower, wchr( &hC9 ), true ) )
		CU_ASSERT( StartsWith( upper, "caf", true ) )
		CU_ASSERT_EQUAL( Tally( upper, wchr( &hE9 ), true ), 1 )
		CU_ASSERT_EQUAL( Tally( upper, wchr( &hE9 ) ), 0 )
		CU_ASSERT_EQUAL( TallyChars( lower, wchr( &hC9 ), true ), 1 )

		'' the byte family does NOT fold above 127, deliberately
		dim as string b = "caf" & chr( &hE9 )
		CU_ASSERT_EQUAL( Contains( b, chr( &hC9 ), true ), false )
	END_TEST

	TEST( byte_family_utf8_pattern_roundtrip )
		'' The byte family's pattern arrives as UTF-16 and is encoded back to
		'' UTF-8 before the search. Nothing above would notice if that encode
		'' were wrong, because an ASCII pattern survives almost any bug in it.
		'' These are the assertions that actually exercise it.
		''
		'' A UTF-8 STRING searched for a non-ASCII pattern must match, and the
		'' POSITION must be a BYTE position -- the haystack is never converted.

		dim as string utf8 = "caf" & chr( &hC3 ) & chr( &hA9 ) & " au lait"
		CU_ASSERT_EQUAL( len( utf8 ), 13 )          '' BYTES: 3 + 2 + 8

		'' pattern literal "e-acute" -> ustring U+00E9 -> back to C3 A9
		CU_ASSERT( Contains( utf8, wchr( &hE9 ) ) )
		CU_ASSERT_EQUAL( Tally( utf8, wchr( &hE9 ) ), 1 )
		CU_ASSERT( EndsWith( "caf" & chr( &hC3 ) & chr( &hA9 ), wchr( &hE9 ) ) )
		CU_ASSERT( StartsWith( utf8, "caf" ) )

		'' a multi-byte pattern of more than one character
		dim as string many = "xx" & chr( &hC3 ) & chr( &hA9 ) & chr( &hC3 ) & chr( &hA8 ) & "yy"
		CU_ASSERT_EQUAL( len( many ), 8 )
		CU_ASSERT_EQUAL( Tally( many, wchr( &hE9 ) & wchr( &hE8 ) ), 1 )
	END_TEST

	TEST( byte_family_charset_is_bytes )
		'' A WART, asserted so it is a decision and not a surprise.
		''
		'' On the BYTE family the character-set functions -- InstrChars,
		'' TallyChars, VerifySet, SpanOf -- operate on BYTES, because a STRING
		'' is bytes. Put a multi-byte character in the set and each of its
		'' bytes joins the set individually, so it matches either half.
		''
		'' There is no way to do better without deciding the haystack's
		'' encoding, which a STRING does not carry. Callers wanting character
		'' sets over non-ASCII text want the USTRING overload, where a set
		'' member is a code unit. The substring functions -- Tally, Contains,
		'' StartsWith, EndsWith -- are unaffected: they match the whole byte
		'' sequence and are exact.

		dim as string many = "xx" & chr( &hC3 ) & chr( &hA9 ) & chr( &hC3 ) & chr( &hA8 ) & "yy"

		'' U+00E8 encodes to C3 A8; the FIRST of those bytes appears at 3,
		'' as the lead byte of the PRECEDING character
		CU_ASSERT_EQUAL( InstrChars( 1, many, wchr( &hE8 ) ), 3 )

		'' and it counts every C3 and every A8: 2 + 1 = 3
		CU_ASSERT_EQUAL( TallyChars( many, wchr( &hE8 ) ), 3 )

		'' the USTRING overload gets this right, because a set member there
		'' is one code unit
		dim as ustring umany = "xx" & wchr( &hE9 ) & wchr( &hE8 ) & "yy"
		CU_ASSERT_EQUAL( len( umany ), 6 )
		CU_ASSERT_EQUAL( InstrChars( 1, umany, wchr( &hE8 ) ), 4 )
		CU_ASSERT_EQUAL( TallyChars( umany, wchr( &hE8 ) ), 1 )

		'' the substring functions are exact on BOTH
		CU_ASSERT_EQUAL( Tally( many, wchr( &hE8 ) ), 1 )
		CU_ASSERT_EQUAL( Tally( umany, wchr( &hE8 ) ), 1 )
	END_TEST

	TEST( byte_family_long_pattern )

		'' a pattern longer than the 128-byte stack buffer, so hPatArg takes
		'' its malloc path -- the branch nothing else here reaches
		dim as ustring longpat
		for i as integer = 1 to 100
			longpat &= wchr( &hE9 )              '' 100 chars = 200 UTF-8 bytes
		next
		CU_ASSERT_EQUAL( len( longpat ), 100 )

		dim as string longhay = ""
		for i as integer = 1 to 100
			longhay &= chr( &hC3 ) & chr( &hA9 )
		next
		CU_ASSERT_EQUAL( len( longhay ), 200 )
		CU_ASSERT_EQUAL( Tally( longhay, longpat ), 1 )
		CU_ASSERT( Contains( longhay, longpat ) )
		CU_ASSERT( StartsWith( longhay, longpat ) )
		CU_ASSERT_EQUAL( Tally( longhay & "z", longpat ), 1 )
		CU_ASSERT_EQUAL( Tally( "z" & longhay, longpat ), 1 )

		'' and the malloc path repeatedly, so a missing free would show
		dim as long acc = 0
		for i as integer = 1 to 5000
			acc += Tally( longhay, longpat )
		next
		CU_ASSERT_EQUAL( acc, 5000 )
	END_TEST

	TEST( unicode_astral_is_two_units )
		'' An astral character is a surrogate pair and therefore 2 code
		'' units. Searching is by code unit, and that is safe: a surrogate
		'' half can never equal a BMP unit, so a match cannot land
		'' mid-character. Asserted, not assumed.
		dim as ustring astral = "𝄞"
		CU_ASSERT_EQUAL( len( astral ), 2 )

		dim as ustring hay = "a" & astral & "b"
		CU_ASSERT_EQUAL( len( hay ), 4 )
		CU_ASSERT( Contains( hay, astral ) )
		CU_ASSERT_EQUAL( Tally( hay, astral ), 1 )
		CU_ASSERT_EQUAL( InstrChars( 1, hay, astral ), 2 )  '' its high half
		CU_ASSERT( StartsWith( hay, "a" ) )
		CU_ASSERT( EndsWith( hay, "b" ) )

		'' two astral chars in a row: 4 units, still counted once each
		dim as ustring two = astral & astral
		CU_ASSERT_EQUAL( len( two ), 4 )
		CU_ASSERT_EQUAL( Tally( two, astral ), 2 )

		'' astral has no simple case mapping -- folding must not corrupt it
		CU_ASSERT_EQUAL( Tally( two, astral, true ), 2 )
		CU_ASSERT_EQUAL( TallyChars( hay, astral ), 2 )     '' both halves
	END_TEST

	'' ------------------------------------------------------ consistency
	''
	'' The three overloads must agree. This is the check that a wstring or
	'' ustring argument did not quietly bind to the byte implementation --
	'' the exact failure the rejected four-overload set produced.

	TEST( overloads_agree )
		dim as string      s = "Hello World"
		dim as zstring * 16 z = "Hello World"
		dim as wstring * 16 w = "Hello World"
		dim as ustring      u = "Hello World"

		CU_ASSERT_EQUAL( Tally( s, "o" ), Tally( z, "o" ) )
		CU_ASSERT_EQUAL( Tally( s, "o" ), Tally( w, "o" ) )
		CU_ASSERT_EQUAL( Tally( s, "o" ), Tally( u, "o" ) )

		CU_ASSERT_EQUAL( TallyChars( s, "lo" ), TallyChars( w, "lo" ) )
		CU_ASSERT_EQUAL( TallyChars( s, "lo" ), TallyChars( u, "lo" ) )

		CU_ASSERT_EQUAL( InstrChars( 1, s, "oW" ), InstrChars( 1, w, "oW" ) )
		CU_ASSERT_EQUAL( InstrChars( 1, s, "oW" ), InstrChars( 1, u, "oW" ) )

		CU_ASSERT_EQUAL( VerifySet( 1, s, "Helo " ), VerifySet( 1, w, "Helo " ) )
		CU_ASSERT_EQUAL( VerifySet( 1, s, "Helo " ), VerifySet( 1, u, "Helo " ) )

		CU_ASSERT_EQUAL( SpanOf( 1, s, "Hel" ), SpanOf( 1, w, "Hel" ) )
		CU_ASSERT_EQUAL( SpanOf( 1, s, "Hel" ), SpanOf( 1, u, "Hel" ) )

		CU_ASSERT_EQUAL( StartsWith( s, "hello", true ), StartsWith( u, "hello", true ) )
		CU_ASSERT_EQUAL( EndsWith( s, "WORLD", true ), EndsWith( u, "WORLD", true ) )
		CU_ASSERT_EQUAL( Contains( s, "LO W", true ), Contains( u, "LO W", true ) )
	END_TEST

	'' ------------------------------------------------------------ leaks
	''
	'' Every wide call built a temporary descriptor somewhere: a fixed-length
	'' ustring becomes one, and on a 32-bit-wchar target every wstring call
	'' re-encodes into one. A missed release would not change any answer, so
	'' nothing above would catch it -- only running the calls enough times to
	'' exhaust something does.

	TEST( no_temp_descriptor_leak )
		dim as ustring * 16 uf = "abcabc"
		dim as wstring * 16 wf = "abcabc"
		dim as ustring       u = "abcabc"
		dim as long acc = 0

		for i as integer = 1 to 20000
			acc += Tally( uf, "abc" )
			acc += Tally( wf, "abc" )
			acc += Tally( u & "", "abc" )
			acc += InstrChars( 1, wf, "c" )
			acc += cint( Contains( wf, "bc" ) )
		next

		'' 2 + 2 + 2 + 3 + (-1) per iteration
		CU_ASSERT_EQUAL( acc, 20000 * 8 )
	END_TEST

END_SUITE
