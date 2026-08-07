'' FB.* pad, wrap, escape and predicates -- exhaustive.
''
'' Nine functions x four argument types. Three things here are not just edge
'' cases but properties, and are tested as such:
''
''   1. PAD ALWAYS RETURNS EXACTLY `width`. Shorter, longer, equal, zero,
''      negative -- the length is the field width or nothing.
''
''   2. UNESCAPE IS THE EXACT INVERSE OF ESCAPE, for every input including
''      strings that already contain backslashes and every byte value 0..255.
''      A round trip over the whole range is worth more than any list of cases.
''
''   3. UNWRAP TAKES ONE PAIR OR NOTHING. AfxStrUnWrap strips repeated and
''      unpaired delimiters; the cases where the two answers differ are the
''      point of the function.

#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

SUITE( fbc_tests.string_.fbstr_pad )

	'' ------------------------------------------------------------- pad

	TEST( pad_string )
		CU_ASSERT_EQUAL( PadRight( "FreeBasic", 12, "*" ), "FreeBasic***" )
		CU_ASSERT_EQUAL( PadLeft(  "FreeBasic", 12, "*" ), "***FreeBasic" )
		CU_ASSERT_EQUAL( PadCenter( "FreeBasic", 13, "*" ), "**FreeBasic**" )

		'' the default pad is a space
		CU_ASSERT_EQUAL( PadRight( "ab", 5 ), "ab   " )
		CU_ASSERT_EQUAL( PadLeft( "ab", 5 ), "   ab" )

		'' the odd unit goes RIGHT when centring
		CU_ASSERT_EQUAL( PadCenter( "a", 4, "-" ), "-a--" )
		CU_ASSERT_EQUAL( PadCenter( "a", 5, "-" ), "--a--" )
		CU_ASSERT_EQUAL( PadCenter( "ab", 5, "-" ), "-ab--" )

		'' exact fit: no padding, no truncation
		CU_ASSERT_EQUAL( PadRight( "abc", 3, "-" ), "abc" )
		CU_ASSERT_EQUAL( PadLeft( "abc", 3, "-" ), "abc" )
		CU_ASSERT_EQUAL( PadCenter( "abc", 3, "-" ), "abc" )

		'' LONGER THAN THE FIELD IS TRUNCATED, keeping the left
		CU_ASSERT_EQUAL( PadRight( "abcdef", 3, "-" ), "abc" )
		CU_ASSERT_EQUAL( PadLeft( "abcdef", 3, "-" ), "abc" )
		CU_ASSERT_EQUAL( PadCenter( "abcdef", 3, "-" ), "abc" )

		'' zero and negative widths
		CU_ASSERT_EQUAL( PadRight( "abc", 0, "-" ), "" )
		CU_ASSERT_EQUAL( PadLeft( "abc", -5, "-" ), "" )
		CU_ASSERT_EQUAL( PadCenter( "abc", 0, "-" ), "" )

		'' empty input pads to a full field
		CU_ASSERT_EQUAL( PadRight( "", 3, "-" ), "---" )
		CU_ASSERT_EQUAL( PadLeft( "", 3, "-" ), "---" )
		CU_ASSERT_EQUAL( PadCenter( "", 4, "-" ), "----" )

		'' a pad that is not exactly one unit falls back to a space
		CU_ASSERT_EQUAL( PadRight( "ab", 5, "" ), "ab   " )
		CU_ASSERT_EQUAL( PadRight( "ab", 5, "xy" ), "ab   " )

		'' THE LENGTH IS THE FIELD WIDTH, always
		CU_ASSERT_EQUAL( len( PadRight( "a", 7, "-" ) ), 7 )
		CU_ASSERT_EQUAL( len( PadLeft( "abcdefghij", 7, "-" ) ), 7 )
		CU_ASSERT_EQUAL( len( PadCenter( "", 7, "-" ) ), 7 )
	END_TEST

	'' ------------------------------------------------------------ wrap

	TEST( wrap_string )
		CU_ASSERT_EQUAL( Wrap( "Paul", "<", ">" ), "<Paul>" )
		CU_ASSERT_EQUAL( Wrap( "Paul", "'" ), "'Paul'" )      '' closing = opening
		CU_ASSERT_EQUAL( Wrap( "Paul" ), """Paul""" )          '' default: quotes

		CU_ASSERT_EQUAL( Wrap( "", "<", ">" ), "<>" )
		CU_ASSERT_EQUAL( Wrap( "x", "", "" ), "x" )            '' nothing to add
		CU_ASSERT_EQUAL( Wrap( "x", "[[", "]]" ), "[[x]]" )    '' multi-character

		'' Wrap then Unwrap is the identity when the pair is well formed
		CU_ASSERT_EQUAL( Unwrap( Wrap( "Paul", "<", ">" ), "<", ">" ), "Paul" )
		CU_ASSERT_EQUAL( Unwrap( Wrap( "Paul" ) ), "Paul" )
	END_TEST

	TEST( unwrap_string )
		CU_ASSERT_EQUAL( Unwrap( "<Paul>", "<", ">" ), "Paul" )
		CU_ASSERT_EQUAL( Unwrap( "'Paul'", "'" ), "Paul" )
		CU_ASSERT_EQUAL( Unwrap( """Paul""" ), "Paul" )

		'' UNBALANCED IS UNTOUCHED -- both ends or neither
		CU_ASSERT_EQUAL( Unwrap( "<Paul", "<", ">" ), "<Paul" )
		CU_ASSERT_EQUAL( Unwrap( "Paul>", "<", ">" ), "Paul>" )
		CU_ASSERT_EQUAL( Unwrap( "Paul", "<", ">" ), "Paul" )

		'' ONE PAIR, not all of them. AfxStrUnWrap uses LTRIM/RTRIM and would
		'' strip every quote here.
		CU_ASSERT_EQUAL( Unwrap( "''x''", "'" ), "'x'" )
		CU_ASSERT_EQUAL( Unwrap( Unwrap( "''x''", "'" ), "'" ), "x" )

		'' the two delimiters must not overlap: one quote is not both ends
		CU_ASSERT_EQUAL( Unwrap( "'", "'" ), "'" )
		CU_ASSERT_EQUAL( Unwrap( "''", "'" ), "" )
		CU_ASSERT_EQUAL( Unwrap( "<>", "<", ">" ), "" )

		'' empty delimiters do nothing
		CU_ASSERT_EQUAL( Unwrap( "abc", "", "" ), "abc" )
		CU_ASSERT_EQUAL( Unwrap( "", "<", ">" ), "" )

		'' multi-character
		CU_ASSERT_EQUAL( Unwrap( "[[x]]", "[[", "]]" ), "x" )
		CU_ASSERT_EQUAL( Unwrap( "[x]]", "[[", "]]" ), "[x]]" )

		'' case
		CU_ASSERT_EQUAL( Unwrap( "AxB", "a", "b" ), "AxB" )
		CU_ASSERT_EQUAL( Unwrap( "AxB", "a", "b", true ), "x" )
	END_TEST

	'' ---------------------------------------------------------- escape

	TEST( escape_string )
		CU_ASSERT_EQUAL( Escape( "a\b" ), "a\\b" )
		CU_ASSERT_EQUAL( Escape( "say " & """" & "hi" & """" ), "say \" & """" & "hi\" & """" )
		CU_ASSERT_EQUAL( Escape( "a" & chr(10) & "b" ), "a\nb" )
		CU_ASSERT_EQUAL( Escape( "a" & chr(13) & "b" ), "a\rb" )
		CU_ASSERT_EQUAL( Escape( "a" & chr(9) & "b" ), "a\tb" )
		CU_ASSERT_EQUAL( Escape( "a" & chr(0) & "b" ), "a\0b" )

		'' other controls become \xHH, upper-case hex
		CU_ASSERT_EQUAL( Escape( chr(1) ), "\x01" )
		CU_ASSERT_EQUAL( Escape( chr(27) ), "\x1B" )
		CU_ASSERT_EQUAL( Escape( chr(127) ), "\x7F" )

		'' nothing to escape, and empty
		CU_ASSERT_EQUAL( Escape( "plain text 123" ), "plain text 123" )
		CU_ASSERT_EQUAL( Escape( "" ), "" )

		'' non-ASCII passes through untouched -- deliberately
		dim as string utf8 = "caf" & chr( &hC3 ) & chr( &hA9 )
		CU_ASSERT_EQUAL( Escape( utf8 ), utf8 )
		CU_ASSERT_EQUAL( len( Escape( utf8 ) ), 5 )
	END_TEST

	TEST( unescape_string )
		CU_ASSERT_EQUAL( Unescape( "a\\b" ), "a\b" )
		CU_ASSERT_EQUAL( Unescape( "a\nb" ), "a" & chr(10) & "b" )
		CU_ASSERT_EQUAL( Unescape( "a\rb" ), "a" & chr(13) & "b" )
		CU_ASSERT_EQUAL( Unescape( "a\tb" ), "a" & chr(9) & "b" )
		CU_ASSERT_EQUAL( Unescape( "a\0b" ), "a" & chr(0) & "b" )
		CU_ASSERT_EQUAL( Unescape( "\x41" ), "A" )
		CU_ASSERT_EQUAL( Unescape( "\x7f" ), chr(127) )      '' lower-case hex too

		'' an unrecognised escape yields the escaped character
		CU_ASSERT_EQUAL( Unescape( "\q" ), "q" )
		CU_ASSERT_EQUAL( Unescape( "a\" & """" & "b" ), "a" & """" & "b" )

		'' a trailing lone backslash has nothing to unquote and is kept
		CU_ASSERT_EQUAL( Unescape( "abc\" ), "abc\" )
		CU_ASSERT_EQUAL( Unescape( "\" ), "\" )

		'' a malformed \x falls back to the 'x'
		CU_ASSERT_EQUAL( Unescape( "\xZZ" ), "xZZ" )
		CU_ASSERT_EQUAL( Unescape( "\x4" ), "x4" )

		CU_ASSERT_EQUAL( Unescape( "" ), "" )
		CU_ASSERT_EQUAL( Unescape( "plain" ), "plain" )
	END_TEST

	TEST( escape_roundtrips_every_byte )
		'' THE PROPERTY, not a list of cases: Unescape( Escape( s ) ) = s.
		'' Run over every byte value 0..255 individually, then over the whole
		'' range as one string, so no value is special-cased by accident.
		for i as integer = 0 to 255
			dim as string one = chr( i )
			dim as string back = Unescape( Escape( one ) )
			CU_ASSERT_EQUAL( len( back ), 1 )
			CU_ASSERT_EQUAL( back[0], i )
		next

		dim as string all_ = ""
		for i as integer = 0 to 255
			all_ &= chr( i )
		next
		CU_ASSERT_EQUAL( len( all_ ), 256 )
		CU_ASSERT_EQUAL( Unescape( Escape( all_ ) ), all_ )

		'' strings that already contain backslashes must survive too
		CU_ASSERT_EQUAL( Unescape( Escape( "a\nb" ) ), "a\nb" )
		CU_ASSERT_EQUAL( Unescape( Escape( "\\\\" ) ), "\\\\" )
		CU_ASSERT_EQUAL( Unescape( Escape( "\x41" ) ), "\x41" )
	END_TEST

	'' ------------------------------------------------------ predicates

	TEST( isnumeric_string )
		'' plain integers
		CU_ASSERT( IsNumeric( "0" ) )
		CU_ASSERT( IsNumeric( "123" ) )
		CU_ASSERT( IsNumeric( "-123" ) )
		CU_ASSERT( IsNumeric( "+123" ) )

		'' fractions
		CU_ASSERT( IsNumeric( "1.5" ) )
		CU_ASSERT( IsNumeric( "-1.5" ) )
		CU_ASSERT( IsNumeric( ".5" ) )
		CU_ASSERT( IsNumeric( "1." ) )

		'' exponents, both markers and both signs
		CU_ASSERT( IsNumeric( "1e5" ) )
		CU_ASSERT( IsNumeric( "1E5" ) )
		CU_ASSERT( IsNumeric( "1d5" ) )
		CU_ASSERT( IsNumeric( "1.5e+3" ) )
		CU_ASSERT( IsNumeric( "-1.5E-3" ) )

		'' surrounding whitespace is allowed
		CU_ASSERT( IsNumeric( "  42  " ) )
		CU_ASSERT( IsNumeric( " -1.5e+3 " ) )

		'' AND THE FALSE CASES, which is where AfxIsNumeric disagrees --
		'' it accepts anything drawn from "+-.0123456789"
		CU_ASSERT_EQUAL( IsNumeric( "" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "   " ), false )
		CU_ASSERT_EQUAL( IsNumeric( "+" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "-" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "." ), false )
		CU_ASSERT_EQUAL( IsNumeric( "++--.." ), false )
		CU_ASSERT_EQUAL( IsNumeric( "1.2.3" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "12abc" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "abc" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "e5" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "1e" ), false )      '' marker, no digits
		CU_ASSERT_EQUAL( IsNumeric( "1e+" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "1 2" ), false )
		CU_ASSERT_EQUAL( IsNumeric( "1-2" ), false )

		'' radix literals are out of scope, stated and asserted
		CU_ASSERT_EQUAL( IsNumeric( "&HFF" ), false )
	END_TEST

	TEST( isblank_string )
		CU_ASSERT( IsBlank( "" ) )
		CU_ASSERT( IsBlank( " " ) )
		CU_ASSERT( IsBlank( "   " ) )
		CU_ASSERT( IsBlank( chr(9) ) )
		CU_ASSERT( IsBlank( chr(10) ) )
		CU_ASSERT( IsBlank( chr(11) ) )
		CU_ASSERT( IsBlank( chr(12) ) )
		CU_ASSERT( IsBlank( chr(13) ) )
		CU_ASSERT( IsBlank( " " & chr(9) & chr(13) & chr(10) ) )

		CU_ASSERT_EQUAL( IsBlank( "a" ), false )
		CU_ASSERT_EQUAL( IsBlank( "  a  " ), false )
		CU_ASSERT_EQUAL( IsBlank( chr(0) ), false )     '' NUL is not whitespace
	END_TEST

	'' ==================================================================
	'' THE OTHER THREE TYPES
	'' ==================================================================

	TEST( pad_zstring )
		dim as zstring * 16 z = "FreeBasic"
		CU_ASSERT_EQUAL( PadRight( z, 12, "*" ), "FreeBasic***" )
		CU_ASSERT_EQUAL( PadLeft( z, 12, "*" ), "***FreeBasic" )
		CU_ASSERT_EQUAL( Wrap( z, "<", ">" ), "<FreeBasic>" )
		CU_ASSERT_EQUAL( Unwrap( "<x>", "<", ">" ), "x" )

		dim as zstring * 8 n = "42"
		CU_ASSERT( IsNumeric( n ) )
		CU_ASSERT_EQUAL( IsBlank( n ), false )
	END_TEST

	TEST( pad_ustring )
		dim as ustring u = "FreeBasic"

		dim as ustring r = PadRight( u, 12, "*" )
		CU_ASSERT_EQUAL( r, "FreeBasic***" )
		CU_ASSERT_EQUAL( len( r ), 12 )

		CU_ASSERT_EQUAL( PadLeft( u, 12, "*" ), "***FreeBasic" )
		CU_ASSERT_EQUAL( PadCenter( u, 13, "*" ), "**FreeBasic**" )
		CU_ASSERT_EQUAL( PadRight( u, 3 ), "Fre" )
		CU_ASSERT_EQUAL( Wrap( u, "<", ">" ), "<FreeBasic>" )
		CU_ASSERT_EQUAL( Unwrap( Wrap( u, "<", ">" ), "<", ">" ), "FreeBasic" )

		dim as ustring nu = " -1.5e+3 "
		CU_ASSERT( IsNumeric( nu ) )
		dim as ustring bu = "  " & wchr(9)
		CU_ASSERT( IsBlank( bu ) )

		'' A BMP PAD CHARACTER WORKS ON THE WIDE FAMILY, where a unit is a
		'' code unit -- and does NOT on the byte family, where it is two
		'' UTF-8 bytes and falls back to a space.
		CU_ASSERT_EQUAL( PadLeft( u, 11, wchr( &hE9 ) ), _
		                 wchr( &hE9 ) & wchr( &hE9 ) & "FreeBasic" )
		dim as string sb = "FreeBasic"
		CU_ASSERT_EQUAL( PadLeft( sb, 11, wchr( &hE9 ) ), "  FreeBasic" )

		'' an astral pad is two units either way, so it falls back
		CU_ASSERT_EQUAL( PadLeft( u, 11, "𝄞" ), "  FreeBasic" )

		dim as ustring * 16 uf = "FreeBasic"
		CU_ASSERT_EQUAL( PadRight( uf, 12, "*" ), "FreeBasic***" )

		dim as ustring ue = ""
		CU_ASSERT_EQUAL( PadRight( ue, 3, "-" ), "---" )
		CU_ASSERT( IsBlank( ue ) )
		CU_ASSERT_EQUAL( IsNumeric( ue ), false )
	END_TEST

	TEST( pad_wstring_returns_ustring )
		dim as wstring * 16 w = "FreeBasic"

		dim as ustring r = PadRight( w, 12, "*" )
		CU_ASSERT_EQUAL( r, "FreeBasic***" )
		CU_ASSERT_EQUAL( len( r ), 12 )

		CU_ASSERT_EQUAL( PadLeft( w, 12, "*" ), "***FreeBasic" )
		CU_ASSERT_EQUAL( PadCenter( w, 13, "*" ), "**FreeBasic**" )
		CU_ASSERT_EQUAL( Wrap( w, "<", ">" ), "<FreeBasic>" )

		dim as wstring * 16 wq = "<x>"
		CU_ASSERT_EQUAL( Unwrap( wq, "<", ">" ), "x" )

		dim as wstring * 16 we = "a" & wchr(10) & "b"
		CU_ASSERT_EQUAL( Escape( we ), "a\nb" )
		CU_ASSERT_EQUAL( Unescape( Escape( we ) ), "a" & wchr(10) & "b" )

		dim as wstring * 16 wn = "3.14"
		CU_ASSERT( IsNumeric( wn ) )
		dim as wstring * 8 wb = "   "
		CU_ASSERT( IsBlank( wb ) )
	END_TEST

	TEST( escape_unicode_passes_through )
		'' On the wide family too, non-ASCII is untouched -- and a surrogate
		'' pair must not be mistaken for two control units.
		dim as ustring astral = "𝄞"

		'' Built by stepwise appending rather than as one concatenation
		'' expression, because `wstring & ustring` -- wstring on the LEFT --
		'' corrupts the ustring operand in this compiler: it is encoded to
		'' UTF-8 and then decoded through the C locale, so an astral
		'' character becomes four units. `ustring & wstring` is fine.
		''
		'' That is a USTRING bug, not an Escape bug, and writing this the
		'' natural way would only make this test fail for someone else's
		'' reason. Left as a note rather than an assertion, so that fixing
		'' the concatenation does not turn this file red.
		dim as ustring u = "caf"
		u &= wchr( &hE9 )
		u &= astral
		CU_ASSERT_EQUAL( len( u ), 6 )

		CU_ASSERT_EQUAL( Escape( u ), u )
		CU_ASSERT_EQUAL( len( Escape( u ) ), 6 )
		CU_ASSERT_EQUAL( Unescape( Escape( u ) ), u )

		'' controls mixed with astral text still round-trip
		dim as ustring mix = astral
		mix &= wchr(10)
		mix &= wchr( &hE9 )
		mix &= wchr(9)
		CU_ASSERT_EQUAL( len( mix ), 5 )

		dim as ustring want = astral
		want &= "\n"
		want &= wchr( &hE9 )
		want &= "\t"
		CU_ASSERT_EQUAL( Escape( mix ), want )
		CU_ASSERT_EQUAL( Unescape( Escape( mix ) ), mix )

		'' IsBlank / IsNumeric over non-ASCII
		CU_ASSERT_EQUAL( IsBlank( wchr( &hE9 ) ), false )
		CU_ASSERT_EQUAL( IsNumeric( wchr( &hE9 ) ), false )
	END_TEST

	'' ------------------------------------------------- overloads agree

	TEST( pad_overloads_agree )
		dim as string       s = "FreeBasic"
		dim as zstring * 16 z = "FreeBasic"
		dim as wstring * 16 w = "FreeBasic"
		dim as ustring      u = "FreeBasic"

		CU_ASSERT_EQUAL( PadRight( s, 12, "*" ), PadRight( z, 12, "*" ) )
		CU_ASSERT_EQUAL( PadRight( s, 12, "*" ), PadRight( w, 12, "*" ) )
		CU_ASSERT_EQUAL( PadRight( s, 12, "*" ), PadRight( u, 12, "*" ) )
		CU_ASSERT_EQUAL( PadLeft( s, 12, "*" ), PadLeft( u, 12, "*" ) )
		CU_ASSERT_EQUAL( PadCenter( s, 13, "*" ), PadCenter( u, 13, "*" ) )
		CU_ASSERT_EQUAL( Wrap( s, "<", ">" ), Wrap( u, "<", ">" ) )
		CU_ASSERT_EQUAL( Escape( s ), Escape( u ) )
		CU_ASSERT_EQUAL( Unescape( "a\nb" ), Unescape( "a\nb" ) )
		CU_ASSERT_EQUAL( IsNumeric( s ), IsNumeric( u ) )
		CU_ASSERT_EQUAL( IsBlank( s ), IsBlank( u ) )

		dim as string       sn = " -1.5e+3 "
		dim as ustring      un = " -1.5e+3 "
		dim as wstring * 16 wn = " -1.5e+3 "
		CU_ASSERT_EQUAL( IsNumeric( sn ), IsNumeric( un ) )
		CU_ASSERT_EQUAL( IsNumeric( sn ), IsNumeric( wn ) )
		CU_ASSERT( IsNumeric( sn ) )
	END_TEST

	'' ----------------------------------------------------------- leaks

	TEST( pad_no_leak )
		dim as string       s = "the quick brown fox"
		dim as ustring      u = "the quick brown fox"
		dim as wstring * 32 w = "the quick brown fox"
		dim as long acc = 0, once = 0

		once += len( PadRight( s, 40, "." ) )
		once += len( PadLeft( u, 40, "." ) )
		once += len( PadCenter( w, 40, "." ) )
		once += len( Wrap( s, "<", ">" ) )
		once += len( Unwrap( "<x>", "<", ">" ) )
		once += len( Escape( "a" & chr(10) & "b\c" ) )
		once += len( Unescape( "a\nb\\c" ) )
		once += cint( IsNumeric( "42" ) ) * 0
		once += cint( IsBlank( "  " ) ) * 0

		CU_ASSERT( once > 0 )

		for i as integer = 1 to 20000
			acc += len( PadRight( s, 40, "." ) )
			acc += len( PadLeft( u, 40, "." ) )
			acc += len( PadCenter( w, 40, "." ) )
			acc += len( Wrap( s, "<", ">" ) )
			acc += len( Unwrap( "<x>", "<", ">" ) )
			acc += len( Escape( "a" & chr(10) & "b\c" ) )
			acc += len( Unescape( "a\nb\\c" ) )
			acc += cint( IsNumeric( "42" ) ) * 0
			acc += cint( IsBlank( "  " ) ) * 0
		next

		CU_ASSERT_EQUAL( acc, 20000 * once )
	END_TEST

END_SUITE
