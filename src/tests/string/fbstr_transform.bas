'' FB.* transform family -- exhaustive.
''
'' Ten functions x four argument types. These build a new string rather than
'' slicing the old one, so on top of the usual matrix they have to pin:
''
''   1. LENGTH CHANGES. Replace can grow or shrink the string, and the buffer is
''      sized from a count computed by a different function (hTally) than the
''      one that fills it. If those two ever disagree the result is a buffer
''      overrun, so the growth cases are deliberate and heavy.
''
''   2. THE CASCADE QUESTION. Remove is a single pass, so removing "ab" from
''      "aabb" leaves "ab" -- AfxStrRemove restarts at position 1 and leaves "".
''      Asserted explicitly, because it is the one place a caller porting from
''      AfxNova will see a different answer.
''
''   3. REVERSE, which is the only function whose two widths deliberately
''      disagree: surrogate pairs survive on the wide family and bytes reverse
''      blindly on the byte one.

#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

SUITE( fbc_tests.string_.fbstr_transform )

	'' ---------------------------------------------------------- Replace

	TEST( replace_string )
		CU_ASSERT_EQUAL( Replace( "Hello World", "World", "Earth" ), "Hello Earth" )

		'' growth -- the case that overruns if the size and the fill disagree
		CU_ASSERT_EQUAL( Replace( "aaa", "a", "bb" ), "bbbbbb" )
		CU_ASSERT_EQUAL( Replace( "a", "a", "aaaa" ), "aaaa" )
		CU_ASSERT_EQUAL( Replace( "xax", "a", "12345" ), "x12345x" )

		'' shrinkage
		CU_ASSERT_EQUAL( Replace( "aaaa", "aa", "X" ), "XX" )
		CU_ASSERT_EQUAL( Replace( "abcabc", "abc", "z" ), "zz" )

		'' same length
		CU_ASSERT_EQUAL( Replace( "abc", "b", "z" ), "azc" )

		'' NO CASCADE: the replacement contains the pattern and must not be
		'' rescanned, or this hangs
		CU_ASSERT_EQUAL( Replace( "a", "a", "aa" ), "aa" )
		CU_ASSERT_EQUAL( Replace( "ab", "a", "aab" ), "aabb" )

		'' non-overlapping
		CU_ASSERT_EQUAL( Replace( "aaaa", "aa", "-" ), "--" )
		CU_ASSERT_EQUAL( Replace( "aaa", "aa", "-" ), "-a" )

		'' position 1 and the last position
		CU_ASSERT_EQUAL( Replace( "abc", "a", "-" ), "-bc" )
		CU_ASSERT_EQUAL( Replace( "abc", "c", "-" ), "ab-" )
		CU_ASSERT_EQUAL( Replace( "abc", "abc", "-" ), "-" )

		'' empties
		CU_ASSERT_EQUAL( Replace( "abc", "", "X" ), "abc" )     '' empty match
		CU_ASSERT_EQUAL( Replace( "abc", "b", "" ), "ac" )      '' empty with
		CU_ASSERT_EQUAL( Replace( "", "a", "b" ), "" )          '' empty input
		CU_ASSERT_EQUAL( Replace( "abc", "abc", "" ), "" )
		CU_ASSERT_EQUAL( Replace( "abc", "xyz", "-" ), "abc" )  '' no match
		CU_ASSERT_EQUAL( Replace( "ab", "abc", "-" ), "ab" )    '' match longer

		'' case
		CU_ASSERT_EQUAL( Replace( "Hello world", "WORLD", "Earth" ), "Hello world" )
		CU_ASSERT_EQUAL( Replace( "Hello world", "WORLD", "Earth", true ), "Hello Earth" )
	END_TEST

	'' ----------------------------------------------------------- Remove

	TEST( remove_string )
		CU_ASSERT_EQUAL( Remove( "abacadabra", "a" ), "bcdbr" )
		CU_ASSERT_EQUAL( Remove( "Hello World. Welcome", "World" ), "Hello . Welcome" )

		'' THE DIVERGENCE. A single pass leaves "ab"; AfxStrRemove restarts at
		'' position 1, so the deletion creates a match that was not in the
		'' input and it returns "". Remove is exactly Replace with "".
		CU_ASSERT_EQUAL( Remove( "aabb", "ab" ), "ab" )
		CU_ASSERT_EQUAL( Remove( "aabb", "ab" ), Replace( "aabb", "ab", "" ) )
		CU_ASSERT_EQUAL( Remove( "aaa", "a" ), Replace( "aaa", "a", "" ) )

		CU_ASSERT_EQUAL( Remove( "abc", "" ), "abc" )
		CU_ASSERT_EQUAL( Remove( "", "a" ), "" )
		CU_ASSERT_EQUAL( Remove( "abc", "abc" ), "" )
		CU_ASSERT_EQUAL( Remove( "abc", "xyz" ), "abc" )
		CU_ASSERT_EQUAL( Remove( "aXbXc", "x" ), "aXbXc" )
		CU_ASSERT_EQUAL( Remove( "aXbXc", "x", true ), "abc" )
	END_TEST

	'' ---------------------------------------- RemoveChars / RetainChars

	TEST( removechars_retainchars_string )
		CU_ASSERT_EQUAL( RemoveChars( "abacadabra", "bac" ), "dr" )
		CU_ASSERT_EQUAL( RemoveChars( "abc", "" ), "abc" )       '' empty set: nothing
		CU_ASSERT_EQUAL( RemoveChars( "", "abc" ), "" )
		CU_ASSERT_EQUAL( RemoveChars( "abc", "abc" ), "" )
		CU_ASSERT_EQUAL( RemoveChars( "abc", "xyz" ), "abc" )
		CU_ASSERT_EQUAL( RemoveChars( "aAbB", "ab" ), "AB" )
		CU_ASSERT_EQUAL( RemoveChars( "aAbB", "ab", true ), "" )

		'' the exact complement
		CU_ASSERT_EQUAL( RetainChars( "abacadabra", "bc" ), "bcb" )
		'' "abacadabra" minus the d and the r
		CU_ASSERT_EQUAL( RetainChars( "abacadabra", "bac" ), "abacaaba" )
		CU_ASSERT_EQUAL( RetainChars( "abc", "" ), "" )          '' empty set: nothing
		CU_ASSERT_EQUAL( RetainChars( "", "abc" ), "" )
		CU_ASSERT_EQUAL( RetainChars( "abc", "abc" ), "abc" )
		CU_ASSERT_EQUAL( RetainChars( "abc", "xyz" ), "" )
		CU_ASSERT_EQUAL( RetainChars( "aAbB", "ab" ), "ab" )
		CU_ASSERT_EQUAL( RetainChars( "aAbB", "ab", true ), "aAbB" )

		'' the two together reconstruct the input's length
		dim as string src = "the quick brown fox"
		CU_ASSERT_EQUAL( len( RemoveChars( src, "aeiou" ) ) + _
		                 len( RetainChars( src, "aeiou" ) ), len( src ) )
	END_TEST

	'' ---------------------------------------------------- ReplaceChars

	TEST( replacechars_string )
		CU_ASSERT_EQUAL( ReplaceChars( "abacadabra", "bac", "*" ), "*****d**r*" )
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "b", "-" ), "a-c" )
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "", "-" ), "abc" )   '' empty set
		CU_ASSERT_EQUAL( ReplaceChars( "", "a", "-" ), "" )
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "xyz", "-" ), "abc" )

		'' `with_` must be exactly one unit or the call is a no-op
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "b", "" ), "abc" )
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "b", "xy" ), "abc" )

		'' the length is invariant, always
		CU_ASSERT_EQUAL( len( ReplaceChars( "abacadabra", "bac", "*" ) ), 10 )

		CU_ASSERT_EQUAL( ReplaceChars( "aAbB", "ab", "-" ), "-A-B" )
		CU_ASSERT_EQUAL( ReplaceChars( "aAbB", "ab", "-", true ), "----" )
	END_TEST

	'' --------------------------------------------------- RemoveBetween

	TEST( removebetween_string )
		CU_ASSERT_EQUAL( RemoveBetween( "blah blah (text) blah blah", "(", ")" ), _
		                 "blah blah  blah blah" )

		'' removeAll walks the whole string
		CU_ASSERT_EQUAL( RemoveBetween( "var1(34), var2(  73 ), var3(any)", "(", ")", true ), _
		                 "var1, var2, var3" )

		'' without it, only the first pair goes
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b(2)c", "(", ")" ), "ab(2)c" )
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b(2)c", "(", ")", true ), "abc" )

		'' an unbalanced opener leaves the tail alone
		CU_ASSERT_EQUAL( RemoveBetween( "a(bc", "(", ")" ), "a(bc" )
		CU_ASSERT_EQUAL( RemoveBetween( "abc)", "(", ")" ), "abc)" )
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b(2", "(", ")", true ), "ab(2" )

		'' adjacent delimiters, whole string, empties
		CU_ASSERT_EQUAL( RemoveBetween( "a()b", "(", ")" ), "ab" )
		CU_ASSERT_EQUAL( RemoveBetween( "(abc)", "(", ")" ), "" )
		CU_ASSERT_EQUAL( RemoveBetween( "", "(", ")" ), "" )
		CU_ASSERT_EQUAL( RemoveBetween( "abc", "(", ")" ), "abc" )
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b", "", ")" ), "a(1)b" )
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b", "(", "" ), "a(1)b" )

		'' multi-character delimiters
		CU_ASSERT_EQUAL( RemoveBetween( "x<!--c-->y", "<!--", "-->" ), "xy" )

		'' start
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b(2)c", "(", ")", true, 5 ), "a(1)bc" )
		CU_ASSERT_EQUAL( RemoveBetween( "a(1)b", "(", ")", false, 0 ), "a(1)b" )

		CU_ASSERT_EQUAL( RemoveBetween( "a[1]b", "A", "B" ), "a[1]b" )
		CU_ASSERT_EQUAL( RemoveBetween( "aXbYc", "x", "y", false, 1, true ), "ac" )
	END_TEST

	'' ---------------------------------------------------------- Reverse

	TEST( reverse_string )
		CU_ASSERT_EQUAL( Reverse( "garden" ), "nedrag" )
		CU_ASSERT_EQUAL( Reverse( "" ), "" )
		CU_ASSERT_EQUAL( Reverse( "a" ), "a" )
		CU_ASSERT_EQUAL( Reverse( "ab" ), "ba" )
		CU_ASSERT_EQUAL( Reverse( "abc" ), "cba" )       '' odd length
		CU_ASSERT_EQUAL( Reverse( "abcd" ), "dcba" )     '' even length
		CU_ASSERT_EQUAL( Reverse( Reverse( "hello" ) ), "hello" )
		CU_ASSERT_EQUAL( Reverse( "aaa" ), "aaa" )
	END_TEST

	'' ----------------------------------------------------------- Repeat

	TEST( repeat_string )
		CU_ASSERT_EQUAL( Repeat( 5, "Paul" ), "PaulPaulPaulPaulPaul" )
		CU_ASSERT_EQUAL( Repeat( 1, "ab" ), "ab" )
		CU_ASSERT_EQUAL( Repeat( 3, "ab" ), "ababab" )
		CU_ASSERT_EQUAL( Repeat( 0, "ab" ), "" )
		CU_ASSERT_EQUAL( Repeat( -5, "ab" ), "" )
		CU_ASSERT_EQUAL( Repeat( 3, "" ), "" )
		CU_ASSERT_EQUAL( Repeat( 0, "" ), "" )
		CU_ASSERT_EQUAL( len( Repeat( 100, "xy" ) ), 200 )
	END_TEST

	'' ----------------------------------------------------------- Shrink

	TEST( shrink_string )
		CU_ASSERT_EQUAL( Shrink( ",,, one , two     three, four,", " ," ), _
		                 "one two three four" )

		'' the default mask is a single space
		CU_ASSERT_EQUAL( Shrink( "  a  b  " ), "a b" )
		CU_ASSERT_EQUAL( Shrink( "a b" ), "a b" )
		CU_ASSERT_EQUAL( Shrink( "a     b" ), "a b" )

		'' every run separator becomes mask(1), not whichever one was found
		CU_ASSERT_EQUAL( Shrink( "a,b", " ," ), "a b" )
		CU_ASSERT_EQUAL( Shrink( "a, ,b", " ," ), "a b" )

		'' leading and trailing runs go entirely
		CU_ASSERT_EQUAL( Shrink( "   abc" ), "abc" )
		CU_ASSERT_EQUAL( Shrink( "abc   " ), "abc" )
		CU_ASSERT_EQUAL( Shrink( "   " ), "" )          '' nothing but mask
		CU_ASSERT_EQUAL( Shrink( "" ), "" )

		'' an EMPTY mask returns the input untouched -- AfxStrShrink returns ""
		CU_ASSERT_EQUAL( Shrink( "a  b", "" ), "a  b" )

		'' a mask that matches nothing
		CU_ASSERT_EQUAL( Shrink( "abc", "xyz" ), "abc" )

		'' whitespace mask, the documented use
		dim as string ws = " " & chr(9) & chr(13) & chr(10)
		CU_ASSERT_EQUAL( Shrink( chr(9) & "a" & chr(13) & chr(10) & "b " , ws ), "a b" )
	END_TEST

	'' ------------------------------------------------------------ MCase

	TEST( mcase_string )
		CU_ASSERT_EQUAL( MCase( "hello wide world" ), "Hello Wide World" )
		CU_ASSERT_EQUAL( MCase( "HELLO WIDE WORLD" ), "Hello Wide World" )
		CU_ASSERT_EQUAL( MCase( "hELLO" ), "Hello" )
		CU_ASSERT_EQUAL( MCase( "" ), "" )
		CU_ASSERT_EQUAL( MCase( "a" ), "A" )
		CU_ASSERT_EQUAL( MCase( "   " ), "   " )

		'' any non-alphanumeric starts a word
		CU_ASSERT_EQUAL( MCase( "o'brien" ), "O'Brien" )
		CU_ASSERT_EQUAL( MCase( "jean-luc" ), "Jean-Luc" )
		CU_ASSERT_EQUAL( MCase( "a.b.c" ), "A.B.C" )

		'' where AfxNova's fixed punctuation list has gaps and this does not
		CU_ASSERT_EQUAL( MCase( "foo_bar" ), "Foo_Bar" )
		CU_ASSERT_EQUAL( MCase( "a/b" ), "A/B" )
		CU_ASSERT_EQUAL( MCase( "a" & chr(9) & "b" ), "A" & chr(9) & "B" )

		'' digits are word characters, so they do NOT start a new word
		CU_ASSERT_EQUAL( MCase( "abc123def" ), "Abc123def" )
		CU_ASSERT_EQUAL( MCase( "123abc" ), "123abc" )

		'' the length never changes
		CU_ASSERT_EQUAL( len( MCase( "hello world" ) ), 11 )
	END_TEST

	'' ==================================================================
	'' THE OTHER THREE TYPES
	'' ==================================================================

	TEST( transform_zstring )
		dim as zstring * 24 z = "abacadabra"
		CU_ASSERT_EQUAL( Replace( z, "a", "-" ), "-b-c-d-br-" )
		CU_ASSERT_EQUAL( Remove( z, "a" ), "bcdbr" )
		CU_ASSERT_EQUAL( RemoveChars( z, "bac" ), "dr" )
		CU_ASSERT_EQUAL( RetainChars( z, "bc" ), "bcb" )
		CU_ASSERT_EQUAL( ReplaceChars( z, "bac", "*" ), "*****d**r*" )
		CU_ASSERT_EQUAL( Reverse( z ), "arbadacaba" )
		CU_ASSERT_EQUAL( Repeat( 2, z ), "abacadabraabacadabra" )
		CU_ASSERT_EQUAL( MCase( z ), "Abacadabra" )

		dim as zstring * 4 e = ""
		CU_ASSERT_EQUAL( Replace( e, "a", "b" ), "" )
		CU_ASSERT_EQUAL( Reverse( e ), "" )
	END_TEST

	TEST( transform_ustring )
		dim as ustring u = "abacadabra"

		dim as ustring r = Replace( u, "a", "-" )
		CU_ASSERT_EQUAL( r, "-b-c-d-br-" )
		CU_ASSERT_EQUAL( len( r ), 10 )

		CU_ASSERT_EQUAL( Remove( u, "a" ), "bcdbr" )
		CU_ASSERT_EQUAL( Remove( u, "ab" ), "acadra" )
		CU_ASSERT_EQUAL( RemoveChars( u, "bac" ), "dr" )
		CU_ASSERT_EQUAL( RetainChars( u, "bc" ), "bcb" )
		CU_ASSERT_EQUAL( ReplaceChars( u, "bac", "*" ), "*****d**r*" )
		CU_ASSERT_EQUAL( RemoveBetween( "x(1)y", "(", ")" ), "xy" )
		CU_ASSERT_EQUAL( Reverse( u ), "arbadacaba" )
		CU_ASSERT_EQUAL( Repeat( 2, u ), "abacadabraabacadabra" )
		CU_ASSERT_EQUAL( Shrink( "  a  b  " ), "a b" )
		CU_ASSERT_EQUAL( MCase( u ), "Abacadabra" )

		'' growth on the wide family, where the unit is 2 bytes
		CU_ASSERT_EQUAL( Replace( u, "a", "xyz" ), "xyzbxyzcxyzdxyzbrxyz" )
		CU_ASSERT_EQUAL( len( Replace( u, "a", "xyz" ) ), 20 )

		dim as ustring * 24 uf = "abacadabra"
		CU_ASSERT_EQUAL( Replace( uf, "a", "-" ), "-b-c-d-br-" )
		CU_ASSERT_EQUAL( Reverse( uf ), "arbadacaba" )

		dim as ustring ue = ""
		CU_ASSERT_EQUAL( Replace( ue, "a", "b" ), "" )
		CU_ASSERT_EQUAL( Reverse( ue ), "" )
		CU_ASSERT_EQUAL( Repeat( 3, ue ), "" )
	END_TEST

	TEST( transform_wstring_returns_ustring )
		dim as wstring * 24 w = "abacadabra"

		'' binding the result to a ustring is what proves the wide overload
		'' was chosen
		dim as ustring r = Replace( w, "a", "-" )
		CU_ASSERT_EQUAL( r, "-b-c-d-br-" )
		CU_ASSERT_EQUAL( len( r ), 10 )

		CU_ASSERT_EQUAL( Remove( w, "a" ), "bcdbr" )
		CU_ASSERT_EQUAL( RemoveChars( w, "bac" ), "dr" )
		CU_ASSERT_EQUAL( RetainChars( w, "bc" ), "bcb" )
		CU_ASSERT_EQUAL( ReplaceChars( w, "bac", "*" ), "*****d**r*" )
		CU_ASSERT_EQUAL( Reverse( w ), "arbadacaba" )
		CU_ASSERT_EQUAL( Repeat( 2, w ), "abacadabraabacadabra" )
		CU_ASSERT_EQUAL( MCase( w ), "Abacadabra" )

		dim as wstring * 32 wb = "x(1)y(2)z"
		CU_ASSERT_EQUAL( RemoveBetween( wb, "(", ")", true ), "xyz" )

		dim as wstring * 16 ws = "  a  b  "
		CU_ASSERT_EQUAL( Shrink( ws ), "a b" )

		dim as wstring * 4 we = ""
		CU_ASSERT_EQUAL( Replace( we, "a", "b" ), "" )
		CU_ASSERT_EQUAL( Reverse( we ), "" )
	END_TEST

	'' ================================================================
	'' REVERSE AND SURROGATES -- the one place the widths disagree
	'' ================================================================

	TEST( reverse_keeps_surrogate_pairs )
		dim as ustring astral = "𝄞"
		CU_ASSERT_EQUAL( len( astral ), 2 )

		'' A blind code-unit reverse would emit the low half first, producing
		'' invalid UTF-16 EVERY time -- not occasionally. The pair is kept
		'' together, so a round trip is the identity and the character
		'' survives intact.
		dim as ustring u = "a" & astral & "b"
		dim as ustring rev = Reverse( u )

		CU_ASSERT_EQUAL( len( rev ), 4 )
		CU_ASSERT_EQUAL( rev, "b" & astral & "a" )
		CU_ASSERT_EQUAL( Reverse( rev ), u )

		'' the pair alone, and two of them
		CU_ASSERT_EQUAL( Reverse( astral ), astral )
		dim as ustring two = astral & astral
		CU_ASSERT_EQUAL( len( Reverse( two ) ), 4 )
		CU_ASSERT_EQUAL( Reverse( two ), two )

		'' a pair at each end, with text between
		dim as ustring mix = astral & "xy" & astral
		CU_ASSERT_EQUAL( Reverse( mix ), astral & "yx" & astral )
		CU_ASSERT_EQUAL( Reverse( Reverse( mix ) ), mix )

		'' BMP text is unaffected by the pair logic
		dim as ustring acc = "caf" & wchr( &hE9 )
		CU_ASSERT_EQUAL( Reverse( acc ), wchr( &hE9 ) & "fac" )

		'' THE BYTE FAMILY DOES NOT DO THIS. A STRING has no encoding, so its
		'' bytes reverse blindly -- which mangles multi-byte UTF-8, as
		'' documented. Asserted so the difference is a decision on record.
		dim as string b = "caf" & chr( &hC3 ) & chr( &hA9 )
		dim as string brev = Reverse( b )
		CU_ASSERT_EQUAL( len( brev ), 5 )
		CU_ASSERT_EQUAL( brev[0], &hA9 )        '' the trail byte now leads
		CU_ASSERT_EQUAL( brev[1], &hC3 )
		'' but it is still an involution on the bytes
		CU_ASSERT_EQUAL( Reverse( brev ), b )
	END_TEST

	TEST( transform_unicode )
		'' folding through the generated BMP table
		dim as ustring acc = "caf" & wchr( &hE9 ) & " CAF" & wchr( &hC9 )
		CU_ASSERT_EQUAL( Replace( acc, wchr( &hE9 ), "e" ), "cafe CAF" & wchr( &hC9 ) )
		CU_ASSERT_EQUAL( Replace( acc, wchr( &hE9 ), "e", true ), "cafe CAFe" )
		CU_ASSERT_EQUAL( RemoveChars( acc, wchr( &hE9 ), true ), "caf CAF" )

		'' MCase over accented text: the accent is a word character, so it
		'' does not start a new word, and it has a case mapping of its own
		CU_ASSERT_EQUAL( MCase( "caf" & wchr( &hE9 ) & " noir" ), _
		                 "Caf" & wchr( &hE9 ) & " Noir" )
		CU_ASSERT_EQUAL( MCase( wchr( &hE9 ) & "cole" ), wchr( &hC9 ) & "cole" )

		'' an astral character has no case mapping and must pass through
		dim as ustring astral = "𝄞"
		CU_ASSERT_EQUAL( MCase( astral ), astral )
		CU_ASSERT_EQUAL( len( MCase( astral & "abc" ) ), 5 )

		'' ReplaceChars needs exactly one unit, so an astral `with_` is a
		'' no-op rather than half a character -- on either family.
		CU_ASSERT_EQUAL( ReplaceChars( "abc", "b", astral ), "abc" )

		'' AND THE ONE-UNIT RULE MEANS DIFFERENT THINGS PER FAMILY.
		''
		'' On the WIDE family a unit is a code unit, so any BMP character
		'' substitutes fine:
		dim as ustring ub = "abc"
		CU_ASSERT_EQUAL( ReplaceChars( ub, "b", wchr( &hE9 ) ), "a" & wchr( &hE9 ) & "c" )
		CU_ASSERT_EQUAL( len( ReplaceChars( ub, "b", wchr( &hE9 ) ) ), 3 )

		'' On the BYTE family a unit is a byte, and U+00E9 encodes to the two
		'' UTF-8 bytes C3 A9. There is no one-byte substitution to make, so
		'' the call is a no-op -- it will not write a lone lead byte and call
		'' it a character. This is the rule the header states, asserted.
		dim as string sb = "abc"
		CU_ASSERT_EQUAL( ReplaceChars( sb, "b", wchr( &hE9 ) ), "abc" )

		'' ASCII substitutes on both, identically
		CU_ASSERT_EQUAL( ReplaceChars( sb, "b", "-" ), ReplaceChars( ub, "b", "-" ) )

		'' Repeat on the wide family
		CU_ASSERT_EQUAL( len( Repeat( 3, astral ) ), 6 )
		CU_ASSERT_EQUAL( Repeat( 2, astral ), astral & astral )
	END_TEST

	'' ------------------------------------------------- overloads agree

	TEST( transform_overloads_agree )
		dim as string       s = "the Quick brown FOX"
		dim as zstring * 32 z = "the Quick brown FOX"
		dim as wstring * 32 w = "the Quick brown FOX"
		dim as ustring      u = "the Quick brown FOX"

		CU_ASSERT_EQUAL( Replace( s, "o", "0" ), Replace( z, "o", "0" ) )
		CU_ASSERT_EQUAL( Replace( s, "o", "0" ), Replace( w, "o", "0" ) )
		CU_ASSERT_EQUAL( Replace( s, "o", "0" ), Replace( u, "o", "0" ) )

		CU_ASSERT_EQUAL( Remove( s, "o" ), Remove( u, "o" ) )
		CU_ASSERT_EQUAL( RemoveChars( s, "aeiou" ), RemoveChars( w, "aeiou" ) )
		CU_ASSERT_EQUAL( RetainChars( s, "aeiou" ), RetainChars( u, "aeiou" ) )
		CU_ASSERT_EQUAL( ReplaceChars( s, "aeiou", "." ), ReplaceChars( u, "aeiou", "." ) )
		CU_ASSERT_EQUAL( Reverse( s ), Reverse( u ) )          '' ASCII: same both ways
		CU_ASSERT_EQUAL( Repeat( 2, s ), Repeat( 2, u ) )
		CU_ASSERT_EQUAL( Shrink( s ), Shrink( u ) )
		CU_ASSERT_EQUAL( MCase( s ), MCase( u ) )
		CU_ASSERT_EQUAL( MCase( s ), "The Quick Brown Fox" )
	END_TEST

	'' ----------------------------------------------------------- leaks

	TEST( transform_no_leak )
		dim as string       s = "the quick brown fox jumps over the lazy dog"
		dim as ustring      u = "the quick brown fox jumps over the lazy dog"
		dim as wstring * 64 w = "the quick brown fox jumps over the lazy dog"
		dim as long acc = 0, once = 0

		once += len( Replace( s, "o", "00" ) )
		once += len( Replace( u, "o", "00" ) )
		once += len( Replace( w, "o", "00" ) )
		once += len( Remove( s, "the " ) )
		once += len( RemoveChars( u, "aeiou" ) )
		once += len( RetainChars( w, "aeiou" ) )
		once += len( ReplaceChars( u, "aeiou", "." ) )
		once += len( Reverse( u ) )
		once += len( Repeat( 3, s ) )
		once += len( Shrink( u ) )
		once += len( MCase( w ) )
		once += len( RemoveBetween( "a(1)b(2)c", "(", ")", true ) )

		CU_ASSERT( once > 0 )

		for i as integer = 1 to 20000
			acc += len( Replace( s, "o", "00" ) )
			acc += len( Replace( u, "o", "00" ) )
			acc += len( Replace( w, "o", "00" ) )
			acc += len( Remove( s, "the " ) )
			acc += len( RemoveChars( u, "aeiou" ) )
			acc += len( RetainChars( w, "aeiou" ) )
			acc += len( ReplaceChars( u, "aeiou", "." ) )
			acc += len( Reverse( u ) )
			acc += len( Repeat( 3, s ) )
			acc += len( Shrink( u ) )
			acc += len( MCase( w ) )
			acc += len( RemoveBetween( "a(1)b(2)c", "(", ")", true ) )
		next

		CU_ASSERT_EQUAL( acc, 20000 * once )
	END_TEST

END_SUITE
