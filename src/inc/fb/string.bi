'' fb/string.bi -- FB.* string algorithms
''
''     #include once "fb/string.bi"
''     using FB
''
''     print Tally( "a,b,c", "," )          '' 2
''     print StartsWith( "Hello", "he", true )
''     print SpanOf( 1, "   x", " " )       '' 3
''
'' The portable half of the algorithms every BASIC program ends up rewriting:
'' counting, character-set scanning, prefix and suffix tests. FreeBASIC ships
'' LEFT/RIGHT/MID/INSTR/TRIM and stops.
''
'' Implemented in the runtime (src/rtlib/str_ops.c, ustr_ops.c), not here. This
'' file is declarations. Nothing is a keyword: `Tally`, `Contains` and the rest
'' stay available as your own identifiers until you say `using FB`.
''
'' ---------------------------------------------------------------------------
'' ALL FOUR STRING TYPES, AND WHAT THAT COSTS
''
'' Each function is declared THREE times, and the overload is chosen by the type
'' of the FIRST argument alone -- STRING, WSTRING or USTRING. ZSTRING is served
'' by the STRING overload through fbc's own implicit conversion, which for
'' bytes-to-bytes is exact and involves no locale. So all four types work, and
'' you never name which one you are using.
''
'' EVERY PARAMETER AFTER THE FIRST IS A USTRING, in all three overloads. That is
'' not a preference, it is what makes the set resolvable: fbc ranks an overload
'' on ALL of its parameters, so with per-family types on the second parameter,
''
''     Tally( someWstring, "abc" )        '' error 98: Ambiguous call
''
'' is an ambiguity rather than a choice -- measured, not predicted. Giving the
'' later parameters one shared type moves the whole decision onto the first.
''
'' A fourth `byref as const zstring` overload was tried and REJECTED separately:
'' it captures STRING and USTRING arguments as well, binding them to the wrong
'' implementation silently instead of reporting an ambiguity.
''
'' WHAT THAT COSTS: a pattern handed to the BYTE family is converted UTF-8 ->
'' UTF-16 -> UTF-8 on the way in. For an ASCII or UTF-8 pattern that is exact,
'' and for a LITERAL it costs nothing at run time, because fbc converts string
'' literals to ustring at compile time. It does NOT survive a pattern of
'' arbitrary non-UTF-8 bytes -- searching binary for a raw byte sequence is
'' outside what this library does, and USTRING already draws that same line.
'' The haystack is never converted, so byte positions in a STRING stay byte
'' positions.
''
'' There is no dynamic ZSTRING or WSTRING, so a function cannot return the type
'' it was handed. Nothing here returns text yet, but the rule the later families
'' follow is:
''
''     string, zstring  ->  string        (byte oriented, no encoding assumed)
''     wstring, ustring ->  ustring       (UTF-16 on every target)
''
'' ---------------------------------------------------------------------------
'' CODE UNITS, AND CASE
''
'' Positions and lengths count CODE UNITS, matching LEN, [] and INSTR. On the
'' wide family an astral character is a surrogate pair and so counts as 2. This
'' never splits a character during a SEARCH -- a surrogate half cannot equal a
'' BMP unit -- though MID can still split one, as it always could.
''
'' `ignoreCase` folds ASCII only on the byte family, because a STRING is a byte
'' buffer with no declared encoding and folding above 127 would be guessing at a
'' codepage. The wide family folds through the generated simple BMP table, so it
'' gives the same answer on every machine and in every locale.
''
'' POSITIONS ARE 1-BASED and 0 means "not found", matching INSTR -- NOT the
'' zero-based convention FB.Array uses. Strings and containers are different
'' worlds and each follows its own tradition.

#pragma once

#if __FB_LANG__ <> "fb"
	#error "fb/string.bi requires -lang fb (it uses namespaces)"
#endif

namespace FB

extern "C"

	'' ------------------------------------------------------------- counting
	''
	'' Occurrences are NON-OVERLAPPING: "aaaa" contains "aa" twice, not three
	'' times. That is the count Replace and Split need -- the number of things
	'' that would be replaced, and the number of separators.
	''
	'' An empty `match` counts 0. A zero-width match matches everywhere and
	'' advances nothing, so the alternative is not a number.

	declare function Tally overload alias "fb_StrTally" _
		( byref s as const string, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	declare function Tally overload alias "fb_WStrTally" _
		( byref s as const wstring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	declare function Tally overload alias "fb_UStrTally" _
		( byref s as const ustring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	'' How many units of s appear in the SET of characters `chars`.
	'' TallyChars( "hello world", "lo" ) = 5

	declare function TallyChars overload alias "fb_StrTallyChars" _
		( byref s as const string, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	declare function TallyChars overload alias "fb_WStrTallyChars" _
		( byref s as const wstring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	declare function TallyChars overload alias "fb_UStrTallyChars" _
		( byref s as const ustring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as integer

	'' -------------------------------------------------- character-set scans
	''
	'' The three that take a 1-based `start`. A start below 1 answers 0
	'' rather than clamping, so a position fed back in from a previous call
	'' that returned "not found" cannot silently restart the scan.
	''
	'' ON THE BYTE FAMILY A SET IS A SET OF BYTES.
	''
	'' InstrChars, TallyChars, VerifySet and SpanOf compare one unit at a
	'' time, and on a STRING a unit is a byte. Put a multi-byte character in
	'' `chars` and each of its bytes joins the set separately, so it matches
	'' either half:
	''
	''     dim as string s = "xx" & chr(&hC3) & chr(&hA9) & "yy"  '' UTF-8
	''     InstrChars( 1, s, wchr(&hE8) )     '' 3 -- matched the C3 byte
	''
	'' There is no better answer available: a STRING carries no encoding, so
	'' the set cannot be decoded into characters. Use the USTRING overload for
	'' character sets over non-ASCII text -- there a set member is one code
	'' unit and the answer is 4.
	''
	'' The SUBSTRING functions -- Tally, Contains, StartsWith, EndsWith -- are
	'' unaffected on both families: they match a whole sequence, never a
	'' single unit, so they are exact for any UTF-8 pattern.

	'' First position at or after `start` whose character IS in `chars`,
	'' or 0. The ANY-form of INSTR. An empty `chars` cannot match: 0.
	declare function InstrChars overload alias "fb_StrInstrChars" _
		( byval start as integer, byref s as const string, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function InstrChars overload alias "fb_WStrInstrChars" _
		( byval start as integer, byref s as const wstring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function InstrChars overload alias "fb_UStrInstrChars" _
		( byval start as integer, byref s as const ustring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	'' First position at or after `start` whose character is NOT in `chars`,
	'' or 0 if every one of them is. The classic "is this string made only of
	'' these characters" test: VerifySet( 1, s, "0123456789" ) = 0.
	''
	'' An empty `chars` answers `start`, not 0 -- nothing is in the set, so the
	'' first character already fails it. That is the opposite of InstrChars's
	'' empty-set rule and deliberately so: "find one of nothing" cannot
	'' succeed, "find one that is not among nothing" cannot fail.
	declare function VerifySet overload alias "fb_StrVerifySet" _
		( byval start as integer, byref s as const string, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function VerifySet overload alias "fb_WStrVerifySet" _
		( byval start as integer, byref s as const wstring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function VerifySet overload alias "fb_UStrVerifySet" _
		( byval start as integer, byref s as const ustring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	'' How many characters from `start` onward are in `chars`, stopping at the
	'' first that is not. Always >= 0. SpanOf( 1, "   x", " " ) = 3.
	declare function SpanOf overload alias "fb_StrSpanOf" _
		( byval start as integer, byref s as const string, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function SpanOf overload alias "fb_WStrSpanOf" _
		( byval start as integer, byref s as const wstring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	declare function SpanOf overload alias "fb_UStrSpanOf" _
		( byval start as integer, byref s as const ustring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as integer

	'' ----------------------------------------------------------- predicates
	''
	'' An EMPTY affix is present in every string, the empty one included --
	'' the vacuous-truth answer, and the one that makes a loop over a list of
	'' prefixes behave when the list contains "".

	declare function StartsWith overload alias "fb_StrStartsWith" _
		( byref s as const string, byref prefix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function StartsWith overload alias "fb_WStrStartsWith" _
		( byref s as const wstring, byref prefix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function StartsWith overload alias "fb_UStrStartsWith" _
		( byref s as const ustring, byref prefix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function EndsWith overload alias "fb_StrEndsWith" _
		( byref s as const string, byref suffix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function EndsWith overload alias "fb_WStrEndsWith" _
		( byref s as const wstring, byref suffix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function EndsWith overload alias "fb_UStrEndsWith" _
		( byref s as const ustring, byref suffix as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function Contains overload alias "fb_StrContains" _
		( byref s as const string, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function Contains overload alias "fb_WStrContains" _
		( byref s as const wstring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

	declare function Contains overload alias "fb_UStrContains" _
		( byref s as const ustring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as boolean

end extern

end namespace
