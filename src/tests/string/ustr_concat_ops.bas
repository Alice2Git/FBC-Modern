'' USTRING and the '&' operator -- every operand pairing, both orders.
''
'' '&' does not reach astNewBOP's string handling the way '+' does. It first
'' passes through hToStr(), which coerces anything that is not already text.
'' USTRING and FIXUSTR were missing from that function's two "already text"
'' lists, so a ustring operand was treated as a non-string and converted:
''
''     dim as wstring * 8 w = "ab"
''     dim as ustring     u = "<astral>"
''     dim as ustring     r = w & u
''
'' With a WSTRING on the left, the ustring right operand went through
'' rtlToWstr() -- ustring to UTF-8 to wchar THROUGH THE C LOCALE. The four
'' UTF-8 bytes of an astral character came back as four separate CP-1252
'' characters, so a 2-unit character silently became 4 units of mojibake.
''
'' '+' was unaffected, which is what made it hard to see: the same expression
'' written with '+' was correct and with '&' was not.
''
'' Every pairing is asserted here in BOTH orders, with an astral character as
'' the canary, because the bug only appeared for one operand order and only for
'' text outside the BMP. ASCII would have passed throughout.

#include "fbcunit.bi"

SUITE( fbc_tests.string_.ustr_concat_ops )

	'' U+1D11E, built from its surrogate halves so the expectation does not
	'' depend on how this source file happens to be encoded.
	#define ASTRAL_HI wchr( &hD834 )
	#define ASTRAL_LO wchr( &hDD1E )

	TEST( astral_is_two_units )
		dim as ustring a = ASTRAL_HI
		a &= ASTRAL_LO
		CU_ASSERT_EQUAL( len( a ), 2 )
		CU_ASSERT_EQUAL( a[0], &hD834 )
		CU_ASSERT_EQUAL( a[1], &hDD1E )
	END_TEST

	TEST( concat_amp_every_pairing )
		dim as ustring a = ASTRAL_HI
		a &= ASTRAL_LO

		dim as string      s  = "xy"
		dim as zstring * 8 z  = "xy"
		dim as wstring * 8 w  = "xy"
		dim as ustring     u  = "xy"

		'' --- ustring on the RIGHT: the direction that was broken ---
		scope
			dim as ustring r = w & a
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[2], &hD834 )
			CU_ASSERT_EQUAL( r[3], &hDD1E )
		end scope

		scope
			dim as ustring r = s & a
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[2], &hD834 )
		end scope

		scope
			dim as ustring r = z & a
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[2], &hD834 )
		end scope

		scope
			dim as ustring r = "xy" & a
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[2], &hD834 )
		end scope

		scope
			dim as ustring r = u & a
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[2], &hD834 )
		end scope

		'' --- ustring on the LEFT ---
		scope
			dim as ustring r = a & w
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[0], &hD834 )
			CU_ASSERT_EQUAL( r[1], &hDD1E )
		end scope

		scope
			dim as ustring r = a & s
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[0], &hD834 )
		end scope

		scope
			dim as ustring r = a & "xy"
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[0], &hD834 )
		end scope

		scope
			dim as ustring r = a & u
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[0], &hD834 )
		end scope
	END_TEST

	TEST( concat_amp_agrees_with_plus )
		'' The two operators must produce the same text. '+' was always
		'' correct here, so it is the reference.
		dim as ustring a = ASTRAL_HI
		a &= ASTRAL_LO

		dim as wstring * 8 w = "xy"
		dim as string      s = "xy"
		dim as ustring     u = "xy"

		scope
			dim as ustring viaAmp = w & a
			dim as ustring viaAdd = w + a
			CU_ASSERT_EQUAL( viaAmp, viaAdd )
			CU_ASSERT_EQUAL( len( viaAmp ), len( viaAdd ) )
		end scope

		scope
			dim as ustring viaAmp = a & w
			dim as ustring viaAdd = a + w
			CU_ASSERT_EQUAL( viaAmp, viaAdd )
		end scope

		scope
			dim as ustring viaAmp = s & a
			dim as ustring viaAdd = s + a
			CU_ASSERT_EQUAL( viaAmp, viaAdd )
		end scope

		scope
			dim as ustring viaAmp = u & a
			dim as ustring viaAdd = u + a
			CU_ASSERT_EQUAL( viaAmp, viaAdd )
		end scope
	END_TEST

	TEST( concat_amp_still_coerces_non_text )
		'' The point of '&' is that it stringifies whatever is not text.
		'' Adding USTRING to hToStr's leave-alone lists must not disturb that.
		dim as ustring u = "n="

		CU_ASSERT_EQUAL( u & 42, "n=42" )
		CU_ASSERT_EQUAL( 42 & u, "42n=" )
		CU_ASSERT_EQUAL( u & 1.5, "n=1.5" )

		dim as long n = 7
		CU_ASSERT_EQUAL( u & n, "n=7" )

		'' and the pre-existing narrow behaviour is untouched
		dim as string s = "n="
		CU_ASSERT_EQUAL( s & 42, "n=42" )
		dim as wstring * 8 w = "n="
		CU_ASSERT_EQUAL( w & 42, "n=42" )
	END_TEST

	TEST( concat_amp_bmp_and_ascii )
		'' The BMP and ASCII cases always worked; they are here so a future
		'' change to hToStr cannot fix the astral case by breaking these.
		dim as ustring acc = wchr( &hE9 )
		dim as wstring * 8 w = "caf"

		scope
			dim as ustring r = w & acc
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[3], &hE9 )
		end scope

		scope
			dim as ustring r = acc & w
			CU_ASSERT_EQUAL( len( r ), 4 )
			CU_ASSERT_EQUAL( r[0], &hE9 )
		end scope

		dim as ustring u = "ab"
		scope
			dim as ustring r = w & u
			CU_ASSERT_EQUAL( r, "cafab" )
		end scope
	END_TEST

	TEST( concat_amp_assign )
		'' '&=' takes its own path, and must agree with '&'.
		dim as ustring a = ASTRAL_HI
		a &= ASTRAL_LO

		dim as ustring acc = "xy"
		acc &= a
		CU_ASSERT_EQUAL( len( acc ), 4 )
		CU_ASSERT_EQUAL( acc[2], &hD834 )
		CU_ASSERT_EQUAL( acc[3], &hDD1E )

		dim as wstring * 8 w = "pq"
		acc &= w
		CU_ASSERT_EQUAL( len( acc ), 6 )
		CU_ASSERT_EQUAL( acc[2], &hD834 )

		acc &= 42
		CU_ASSERT_EQUAL( len( acc ), 8 )
	END_TEST

	TEST( concat_amp_chained )
		'' A chain builds left to right, so an early wstring operand used to
		'' poison everything after it.
		dim as ustring a = ASTRAL_HI
		a &= ASTRAL_LO

		dim as wstring * 8 w = "w"
		dim as string      s = "s"
		dim as ustring     u = "u"

		dim as ustring r = w & a & s & a & u
		CU_ASSERT_EQUAL( len( r ), 1 + 2 + 1 + 2 + 1 )
		CU_ASSERT_EQUAL( r[1], &hD834 )
		CU_ASSERT_EQUAL( r[2], &hDD1E )
		CU_ASSERT_EQUAL( r[4], &hD834 )
		CU_ASSERT_EQUAL( r[5], &hDD1E )
	END_TEST

END_SUITE
