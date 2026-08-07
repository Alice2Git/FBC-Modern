'' FB.* extract family -- exhaustive.
''
'' Nine functions x four argument types x the full edge matrix. This is the
'' first family that RETURNS TEXT, so on top of the usual boundaries it has to
'' pin down two things nothing in phase 1 could:
''
''   1. THE RETURN-TYPE RULE. string/zstring -> string, wstring/ustring ->
''      ustring. A wstring argument coming back as a ustring is the surprising
''      one, and it is asserted rather than left to the docs.
''
''   2. THE TEMP-DESCRIPTOR CONTRACT. Every call allocates a result the CALLER
''      frees. A leak changes no answer, so only running the calls in bulk
''      catches it.
''
'' The two asymmetric miss rules get the most attention, because each is
'' defensible in isolation and they disagree with each other on purpose:
''
''     Extract( 1, s, missing )   = the whole remainder
''     Remain( s, missing )       = ""

#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

SUITE( fbc_tests.string_.fbstr_extract )

	'' ---------------------------------------------------------- Extract

	TEST( extract_string )
		'' the AfxStrExtract doc example
		CU_ASSERT_EQUAL( Extract( 1, "abacadabra", "cad" ), "aba" )

		'' A MISS RETURNS THE WHOLE REMAINDER -- the rule that makes a parse
		'' loop terminate instead of silently dropping the last field.
		CU_ASSERT_EQUAL( Extract( 1, "abacadabra", "zzz" ), "abacadabra" )
		CU_ASSERT_EQUAL( Extract( 4, "abacadabra", "zzz" ), "cadabra" )

		'' an empty match is a miss
		CU_ASSERT_EQUAL( Extract( 1, "abc", "" ), "abc" )

		'' match at position 1 -> nothing before it
		CU_ASSERT_EQUAL( Extract( 1, "abc", "a" ), "" )
		'' match at the very end
		CU_ASSERT_EQUAL( Extract( 1, "abc", "c" ), "ab" )
		'' whole string matches
		CU_ASSERT_EQUAL( Extract( 1, "abc", "abc" ), "" )
		'' match longer than the input
		CU_ASSERT_EQUAL( Extract( 1, "abc", "abcd" ), "abc" )

		'' start
		CU_ASSERT_EQUAL( Extract( 2, "abacadabra", "cad" ), "ba" )
		CU_ASSERT_EQUAL( Extract( 5, "abacadabra", "a" ), "" )
		CU_ASSERT_EQUAL( Extract( 0, "abc", "b" ), "" )        '' start < 1
		CU_ASSERT_EQUAL( Extract( -3, "abc", "b" ), "" )
		CU_ASSERT_EQUAL( Extract( 4, "abc", "b" ), "" )        '' start past end
		CU_ASSERT_EQUAL( Extract( 3, "abc", "b" ), "c" )       '' last position

		'' empty input
		CU_ASSERT_EQUAL( Extract( 1, "", "a" ), "" )
		CU_ASSERT_EQUAL( Extract( 1, "", "" ), "" )

		'' case
		CU_ASSERT_EQUAL( Extract( 1, "abaCADabra", "cad" ), "abaCADabra" )
		CU_ASSERT_EQUAL( Extract( 1, "abaCADabra", "cad", true ), "aba" )
	END_TEST

	TEST( extractchars_string )
		CU_ASSERT_EQUAL( ExtractChars( 1, "abacadabra", "cd" ), "aba" )
		CU_ASSERT_EQUAL( ExtractChars( 1, "abc", "xyz" ), "abc" )   '' miss
		CU_ASSERT_EQUAL( ExtractChars( 1, "abc", "" ), "abc" )      '' empty set
		CU_ASSERT_EQUAL( ExtractChars( 1, "abc", "a" ), "" )
		CU_ASSERT_EQUAL( ExtractChars( 1, "abc", "c" ), "ab" )
		CU_ASSERT_EQUAL( ExtractChars( 2, "abacadabra", "cd" ), "ba" )
		CU_ASSERT_EQUAL( ExtractChars( 0, "abc", "b" ), "" )
		CU_ASSERT_EQUAL( ExtractChars( 9, "abc", "b" ), "" )
		CU_ASSERT_EQUAL( ExtractChars( 1, "", "a" ), "" )
		'' "abACadabra": the lowercase 'd' at 6 is in the set even without
		'' folding, so this is a HIT, not a miss. With folding the 'C' at 4
		'' matches first and the answer shortens to "abA".
		CU_ASSERT_EQUAL( ExtractChars( 1, "abACadabra", "cd" ), "abACa" )
		CU_ASSERT_EQUAL( ExtractChars( 1, "abACadabra", "cd", true ), "abA" )
	END_TEST

	'' ----------------------------------------------------------- Remain

	TEST( remain_string )
		'' the AfxStrRemain doc example
		CU_ASSERT_EQUAL( Remain( "Brevity is the soul of wit", "is " ), "the soul of wit" )

		'' A MISS RETURNS "" -- the opposite of Extract, on purpose
		CU_ASSERT_EQUAL( Remain( "abc", "zzz" ), "" )
		CU_ASSERT_EQUAL( Remain( "abc", "" ), "" )         '' empty match
		CU_ASSERT_EQUAL( Remain( "", "a" ), "" )           '' empty input

		CU_ASSERT_EQUAL( Remain( "abc", "a" ), "bc" )      '' match at 1
		CU_ASSERT_EQUAL( Remain( "abc", "c" ), "" )        '' match at the end
		CU_ASSERT_EQUAL( Remain( "abc", "abc" ), "" )      '' whole string
		CU_ASSERT_EQUAL( Remain( "abc", "abcd" ), "" )     '' longer than input
		CU_ASSERT_EQUAL( Remain( "abcabc", "b" ), "cabc" ) '' first occurrence

		'' start
		CU_ASSERT_EQUAL( Remain( "abcabc", "b", 3 ), "c" )
		CU_ASSERT_EQUAL( Remain( "abc", "b", 0 ), "" )
		CU_ASSERT_EQUAL( Remain( "abc", "b", 4 ), "" )
		CU_ASSERT_EQUAL( Remain( "abc", "c", 3 ), "" )

		'' case
		CU_ASSERT_EQUAL( Remain( "aXbc", "x" ), "" )
		CU_ASSERT_EQUAL( Remain( "aXbc", "x", 1, true ), "bc" )
	END_TEST

	TEST( remainchars_string )
		CU_ASSERT_EQUAL( RemainChars( "abacadabra", "cd" ), "adabra" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "xyz" ), "" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "" ), "" )
		CU_ASSERT_EQUAL( RemainChars( "", "a" ), "" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "a" ), "bc" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "c" ), "" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "b", 3 ), "" )
		CU_ASSERT_EQUAL( RemainChars( "abc", "b", 0 ), "" )
		CU_ASSERT_EQUAL( RemainChars( "aXbc", "x" ), "" )
		CU_ASSERT_EQUAL( RemainChars( "aXbc", "x", 1, true ), "bc" )
	END_TEST

	'' ---------------------------------------------------------- Between

	TEST( between_string )
		CU_ASSERT_EQUAL( Between( "blah (text here) blah", "(", ")" ), "text here" )

		'' the closer is searched from the END of the opener, so the first
		'' pair wins and cannot cross into the second
		CU_ASSERT_EQUAL( Between( "(a)(b)", "(", ")" ), "a" )
		CU_ASSERT_EQUAL( Between( "(a)(b)", "(", ")", 4 ), "b" )

		'' either end missing -> ""
		CU_ASSERT_EQUAL( Between( "(abc", "(", ")" ), "" )
		CU_ASSERT_EQUAL( Between( "abc)", "(", ")" ), "" )
		CU_ASSERT_EQUAL( Between( "abc", "(", ")" ), "" )

		'' empty delimiters never match
		CU_ASSERT_EQUAL( Between( "(a)", "", ")" ), "" )
		CU_ASSERT_EQUAL( Between( "(a)", "(", "" ), "" )

		'' adjacent delimiters -> empty content, which is a HIT not a miss
		CU_ASSERT_EQUAL( Between( "()", "(", ")" ), "" )
		CU_ASSERT_EQUAL( Between( "x()y", "(", ")" ), "" )

		'' multi-character delimiters
		CU_ASSERT_EQUAL( Between( "a<!--hi-->b", "<!--", "-->" ), "hi" )

		'' the closer may equal the opener
		CU_ASSERT_EQUAL( Between( "say ""hi"" now", """", """" ), "hi" )

		CU_ASSERT_EQUAL( Between( "", "(", ")" ), "" )
		CU_ASSERT_EQUAL( Between( "(a)", "(", ")", 0 ), "" )
		CU_ASSERT_EQUAL( Between( "(a)", "(", ")", 9 ), "" )

		CU_ASSERT_EQUAL( Between( "[A]", "a", "A" ), "" )
		CU_ASSERT_EQUAL( Between( "xAyAz", "a", "a", 1, true ), "y" )
	END_TEST

	'' ------------------------------------------------ ClipLeft/ClipRight

	TEST( clip_string )
		CU_ASSERT_EQUAL( ClipLeft( "1234567890", 3 ), "4567890" )
		CU_ASSERT_EQUAL( ClipRight( "1234567890", 3 ), "1234567" )

		'' count <= 0 removes nothing
		CU_ASSERT_EQUAL( ClipLeft( "abc", 0 ), "abc" )
		CU_ASSERT_EQUAL( ClipLeft( "abc", -5 ), "abc" )
		CU_ASSERT_EQUAL( ClipRight( "abc", 0 ), "abc" )
		CU_ASSERT_EQUAL( ClipRight( "abc", -5 ), "abc" )

		'' count at or past the length removes everything, never overruns
		CU_ASSERT_EQUAL( ClipLeft( "abc", 3 ), "" )
		CU_ASSERT_EQUAL( ClipLeft( "abc", 4 ), "" )
		CU_ASSERT_EQUAL( ClipLeft( "abc", 9999 ), "" )
		CU_ASSERT_EQUAL( ClipRight( "abc", 3 ), "" )
		CU_ASSERT_EQUAL( ClipRight( "abc", 4 ), "" )
		CU_ASSERT_EQUAL( ClipRight( "abc", 9999 ), "" )

		'' one off each end
		CU_ASSERT_EQUAL( ClipLeft( "abc", 1 ), "bc" )
		CU_ASSERT_EQUAL( ClipRight( "abc", 1 ), "ab" )

		CU_ASSERT_EQUAL( ClipLeft( "", 1 ), "" )
		CU_ASSERT_EQUAL( ClipRight( "", 1 ), "" )
		CU_ASSERT_EQUAL( ClipLeft( "", 0 ), "" )
	END_TEST

	'' --------------------------------------------------------- DeleteAt

	TEST( deleteat_string )
		CU_ASSERT_EQUAL( DeleteAt( "1234567890", 4, 3 ), "1237890" )
		CU_ASSERT_EQUAL( DeleteAt( "1234567890", 1, 3 ), "4567890" )   '' from the front
		CU_ASSERT_EQUAL( DeleteAt( "1234567890", 8, 3 ), "1234567" )   '' to the end
		CU_ASSERT_EQUAL( DeleteAt( "abc", 1, 3 ), "" )                 '' all of it

		'' a count running past the end removes only what is there
		CU_ASSERT_EQUAL( DeleteAt( "abc", 2, 9999 ), "a" )

		'' EVERY invalid argument is a no-op
		CU_ASSERT_EQUAL( DeleteAt( "abc", 0, 1 ), "abc" )       '' start < 1
		CU_ASSERT_EQUAL( DeleteAt( "abc", -2, 1 ), "abc" )
		CU_ASSERT_EQUAL( DeleteAt( "abc", 4, 1 ), "abc" )       '' start past end
		CU_ASSERT_EQUAL( DeleteAt( "abc", 2, 0 ), "abc" )       '' count 0
		CU_ASSERT_EQUAL( DeleteAt( "abc", 2, -3 ), "abc" )      '' count < 0
		CU_ASSERT_EQUAL( DeleteAt( "", 1, 1 ), "" )             '' empty input

		'' last valid position
		CU_ASSERT_EQUAL( DeleteAt( "abc", 3, 1 ), "ab" )
	END_TEST

	'' --------------------------------------------------------- InsertAt

	TEST( insertat_string )
		CU_ASSERT_EQUAL( InsertAt( "1234567890", "--", 6 ), "12345--67890" )
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", 1 ), "-abc" )    '' at the front
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", 3 ), "ab-c" )
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", 4 ), "abc-" )    '' one past the end

		'' past the end APPENDS
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", 99 ), "abc-" )

		'' below 1 does NOT insert -- unchanged, matching DeleteAt
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", 0 ), "abc" )
		CU_ASSERT_EQUAL( InsertAt( "abc", "-", -5 ), "abc" )

		'' empty pieces
		CU_ASSERT_EQUAL( InsertAt( "abc", "", 2 ), "abc" )
		CU_ASSERT_EQUAL( InsertAt( "", "xy", 1 ), "xy" )
		CU_ASSERT_EQUAL( InsertAt( "", "xy", 99 ), "xy" )
		CU_ASSERT_EQUAL( InsertAt( "", "", 1 ), "" )

		'' multi-character insert
		CU_ASSERT_EQUAL( InsertAt( "ac", "bbb", 2 ), "abbbc" )
	END_TEST

	'' ==================================================================
	'' THE OTHER THREE TYPES
	''
	'' ZSTRING goes through the STRING overload and must give byte-identical
	'' answers. WSTRING and USTRING return a USTRING -- asserted by assigning
	'' the result to a ustring and comparing, which would not compile if the
	'' overload had bound to the byte implementation.
	'' ==================================================================

	TEST( extract_zstring )
		dim as zstring * 16 z = "abacadabra"
		CU_ASSERT_EQUAL( Extract( 1, z, "cad" ), "aba" )
		CU_ASSERT_EQUAL( Extract( 1, z, "zzz" ), "abacadabra" )
		CU_ASSERT_EQUAL( Remain( z, "cad" ), "abra" )
		CU_ASSERT_EQUAL( Remain( z, "zzz" ), "" )
		CU_ASSERT_EQUAL( ClipLeft( z, 3 ), "cadabra" )
		CU_ASSERT_EQUAL( ClipRight( z, 5 ), "abaca" )
		CU_ASSERT_EQUAL( DeleteAt( z, 1, 3 ), "cadabra" )
		CU_ASSERT_EQUAL( InsertAt( z, "-", 1 ), "-abacadabra" )

		dim as zstring * 4 e = ""
		CU_ASSERT_EQUAL( Extract( 1, e, "a" ), "" )
		CU_ASSERT_EQUAL( ClipLeft( e, 1 ), "" )
	END_TEST

	TEST( extract_ustring )
		dim as ustring u = "abacadabra"

		'' the result IS a ustring
		dim as ustring r = Extract( 1, u, "cad" )
		CU_ASSERT_EQUAL( r, "aba" )
		CU_ASSERT_EQUAL( len( r ), 3 )

		CU_ASSERT_EQUAL( Extract( 1, u, "zzz" ), "abacadabra" )
		CU_ASSERT_EQUAL( ExtractChars( 1, u, "cd" ), "aba" )
		CU_ASSERT_EQUAL( Remain( u, "cad" ), "abra" )
		CU_ASSERT_EQUAL( Remain( u, "zzz" ), "" )
		CU_ASSERT_EQUAL( RemainChars( u, "cd" ), "adabra" )
		CU_ASSERT_EQUAL( Between( u, "b", "d" ), "aca" )
		CU_ASSERT_EQUAL( ClipLeft( u, 3 ), "cadabra" )
		CU_ASSERT_EQUAL( ClipRight( u, 5 ), "abaca" )
		CU_ASSERT_EQUAL( DeleteAt( u, 4, 3 ), "abaabra" )
		CU_ASSERT_EQUAL( InsertAt( u, "--", 1 ), "--abacadabra" )

		'' the fixed-length form: a compiler-built temp descriptor
		dim as ustring * 16 uf = "abacadabra"
		CU_ASSERT_EQUAL( Extract( 1, uf, "cad" ), "aba" )
		CU_ASSERT_EQUAL( ClipLeft( uf, 3 ), "cadabra" )

		dim as ustring ue = ""
		CU_ASSERT_EQUAL( Extract( 1, ue, "a" ), "" )
		CU_ASSERT_EQUAL( DeleteAt( ue, 1, 1 ), "" )
		CU_ASSERT_EQUAL( InsertAt( ue, "x", 1 ), "x" )
	END_TEST

	TEST( extract_wstring_returns_ustring )
		dim as wstring * 16 w = "abacadabra"

		'' A WSTRING IN GIVES A USTRING OUT. Assigning to a ustring and
		'' checking len() in CODE UNITS is what proves the wide overload was
		'' chosen -- the byte one would have produced a string.
		dim as ustring r = Extract( 1, w, "cad" )
		CU_ASSERT_EQUAL( r, "aba" )
		CU_ASSERT_EQUAL( len( r ), 3 )

		CU_ASSERT_EQUAL( Extract( 1, w, "zzz" ), "abacadabra" )
		CU_ASSERT_EQUAL( ExtractChars( 1, w, "cd" ), "aba" )
		CU_ASSERT_EQUAL( Remain( w, "cad" ), "abra" )
		CU_ASSERT_EQUAL( Remain( w, "zzz" ), "" )
		CU_ASSERT_EQUAL( RemainChars( w, "cd" ), "adabra" )
		CU_ASSERT_EQUAL( Between( w, "b", "d" ), "aca" )
		CU_ASSERT_EQUAL( ClipLeft( w, 3 ), "cadabra" )
		CU_ASSERT_EQUAL( ClipRight( w, 5 ), "abaca" )
		CU_ASSERT_EQUAL( DeleteAt( w, 4, 3 ), "abaabra" )
		CU_ASSERT_EQUAL( InsertAt( w, "--", 1 ), "--abacadabra" )

		dim as wstring * 4 we = ""
		CU_ASSERT_EQUAL( Extract( 1, we, "a" ), "" )
		CU_ASSERT_EQUAL( InsertAt( we, "x", 1 ), "x" )
	END_TEST

	'' -------------------------------------------------------- non-ASCII

	TEST( extract_unicode )
		'' The wide family counts CODE UNITS, so an astral character is 2 and
		'' a position can land between its halves. That is a property of
		'' UTF-16, the same one MID already has, and it is pinned here rather
		'' than discovered.
		dim as ustring astral = "𝄞"
		CU_ASSERT_EQUAL( len( astral ), 2 )

		dim as ustring u = "a" & astral & "b"
		CU_ASSERT_EQUAL( len( u ), 4 )
		CU_ASSERT_EQUAL( Extract( 1, u, "b" ), "a" & astral )
		CU_ASSERT_EQUAL( Remain( u, astral ), "b" )
		CU_ASSERT_EQUAL( Between( u, "a", "b" ), astral )

		'' ClipLeft(1) cuts the "a"; ClipLeft(2) SPLITS THE PAIR, leaving a
		'' lone low surrogate. Asserted by length, because the content is by
		'' definition not well-formed text.
		CU_ASSERT_EQUAL( len( ClipLeft( u, 1 ) ), 3 )
		CU_ASSERT_EQUAL( len( ClipLeft( u, 2 ) ), 2 )
		CU_ASSERT_EQUAL( len( DeleteAt( u, 2, 2 ) ), 2 )   '' removes the whole pair
		CU_ASSERT_EQUAL( DeleteAt( u, 2, 2 ), "ab" )

		'' BMP accents, and folding through the generated table
		dim as ustring acc = "caf" & wchr( &hE9 ) & " noir"
		CU_ASSERT_EQUAL( Extract( 1, acc, wchr( &hE9 ) ), "caf" )
		CU_ASSERT_EQUAL( Remain( acc, wchr( &hE9 ) ), " noir" )
		CU_ASSERT_EQUAL( Extract( 1, acc, wchr( &hC9 ) ), acc )          '' miss
		CU_ASSERT_EQUAL( Extract( 1, acc, wchr( &hC9 ), true ), "caf" )  '' folds

		'' the byte family on UTF-8 bytes: positions and lengths are BYTES
		dim as string b = "caf" & chr( &hC3 ) & chr( &hA9 ) & " noir"
		CU_ASSERT_EQUAL( len( b ), 10 )
		CU_ASSERT_EQUAL( Extract( 1, b, wchr( &hE9 ) ), "caf" )
		CU_ASSERT_EQUAL( Remain( b, wchr( &hE9 ) ), " noir" )
		CU_ASSERT_EQUAL( len( ClipRight( b, 5 ) ), 5 )
	END_TEST

	'' ------------------------------------------------- overloads agree

	TEST( extract_overloads_agree )
		dim as string       s = "Hello (World) Again"
		dim as zstring * 32 z = "Hello (World) Again"
		dim as wstring * 32 w = "Hello (World) Again"
		dim as ustring      u = "Hello (World) Again"

		CU_ASSERT_EQUAL( Extract( 1, s, "(" ), Extract( 1, z, "(" ) )
		CU_ASSERT_EQUAL( Extract( 1, s, "(" ), Extract( 1, w, "(" ) )
		CU_ASSERT_EQUAL( Extract( 1, s, "(" ), Extract( 1, u, "(" ) )

		CU_ASSERT_EQUAL( Remain( s, ")" ), Remain( w, ")" ) )
		CU_ASSERT_EQUAL( Remain( s, ")" ), Remain( u, ")" ) )

		CU_ASSERT_EQUAL( Between( s, "(", ")" ), Between( w, "(", ")" ) )
		CU_ASSERT_EQUAL( Between( s, "(", ")" ), Between( u, "(", ")" ) )
		CU_ASSERT_EQUAL( Between( s, "(", ")" ), "World" )

		CU_ASSERT_EQUAL( ClipLeft( s, 6 ), ClipLeft( w, 6 ) )
		CU_ASSERT_EQUAL( ClipRight( s, 6 ), ClipRight( u, 6 ) )
		CU_ASSERT_EQUAL( DeleteAt( s, 7, 7 ), DeleteAt( u, 7, 7 ) )
		CU_ASSERT_EQUAL( InsertAt( s, "!", 6 ), InsertAt( u, "!", 6 ) )

		CU_ASSERT_EQUAL( ExtractChars( 1, s, "(" ), ExtractChars( 1, u, "(" ) )
		CU_ASSERT_EQUAL( RemainChars( s, ")" ), RemainChars( u, ")" ) )
	END_TEST

	'' ----------------------------------------------------------- leaks
	''
	'' Every one of these allocates a result. A missing release changes no
	'' answer, so the only way to see one is to make enough of them.

	TEST( extract_no_leak )
		dim as string       s = "the quick brown fox jumps over the lazy dog"
		dim as ustring      u = "the quick brown fox jumps over the lazy dog"
		dim as wstring * 64 w = "the quick brown fox jumps over the lazy dog"
		dim as ustring * 64 uf = "the quick brown fox jumps over the lazy dog"
		dim as long acc = 0, once = 0

		'' One pass, to establish what a correct iteration sums to. The
		'' individual VALUES are pinned by the tests above; what this test is
		'' for is that 20,000 more passes neither change the answer nor
		'' exhaust the temp pool, so hand-arithmetic here would only add a
		'' way for the test to be wrong about something it is not testing.
		once += len( Extract( 1, s, "brown" ) )
		once += len( Extract( 1, u, "brown" ) )
		once += len( Extract( 1, w, "brown" ) )
		once += len( Extract( 1, uf, "brown" ) )
		once += len( Remain( s, "fox " ) )
		once += len( Remain( u, "fox " ) )
		once += len( Between( w, "quick", "fox" ) )
		once += len( ClipLeft( u, 4 ) )
		once += len( DeleteAt( s, 1, 4 ) )
		once += len( InsertAt( u, "!!", 1 ) )

		CU_ASSERT( once > 0 )

		for i as integer = 1 to 20000
			acc += len( Extract( 1, s, "brown" ) )
			acc += len( Extract( 1, u, "brown" ) )
			acc += len( Extract( 1, w, "brown" ) )
			acc += len( Extract( 1, uf, "brown" ) )
			acc += len( Remain( s, "fox " ) )
			acc += len( Remain( u, "fox " ) )
			acc += len( Between( w, "quick", "fox" ) )
			acc += len( ClipLeft( u, 4 ) )
			acc += len( DeleteAt( s, 1, 4 ) )
			acc += len( InsertAt( u, "!!", 1 ) )
		next

		CU_ASSERT_EQUAL( acc, 20000 * once )
	END_TEST

END_SUITE
