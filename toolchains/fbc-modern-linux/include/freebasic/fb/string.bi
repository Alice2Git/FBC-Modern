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

#include once "fb/array.bi"

#if __FB_LANG__ <> "fb"
	#error "fb/string.bi requires -lang fb (it uses namespaces)"
#endif

'' ---------------------------------------------------------------------------
'' THE EXTERN BLOCK BELOW MUST MATCH FBCALL, NOT JUST SUPPRESS MANGLING.
''
'' These entry points are FBCALL in the runtime, and FBCALL is __stdcall on
'' HOST_X86 -- win32 -- and nothing everywhere else (src/rtlib/win32/fb_win32.h).
'' So on win32 the runtime exports _fb_StrReplace@16, and a cdecl declaration
'' asks the linker for fb_StrReplace and does not find it.
''
'' `extern "C"` is needed to stop fbc mangling the namespace into the symbol --
'' `alias` alone is not enough inside a NAMESPACE -- but it also forces CDECL,
'' which is wrong on win32. FreeBASIC's own inc/string.bi gets away with a bare
'' `declare ... alias` for FORMAT precisely because it is NOT in a namespace and
'' so keeps the default convention.
''
'' `extern "Windows"` is stdcall with the @N decoration on x86 and the single
'' native convention everywhere else, which is exactly FBCALL's shape. It is
'' used on 32-bit Windows only; every other target keeps `extern "C"`.
''
'' This cost a win32 link failure that win64 could never have shown: with one
'' calling convention, win64 cannot tell the two apart.
#if defined( __FB_WIN32__ ) and ( not defined( __FB_64BIT__ ) )
	#define FBSTR_EXTERN extern "Windows"
#else
	#define FBSTR_EXTERN extern "C"
#endif


namespace FB

FBSTR_EXTERN

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

	'' =====================================================================
	'' EXTRACT -- slicing by content rather than by position
	''
	'' RETURN TYPES. There is no dynamic ZSTRING or WSTRING, so a function
	'' cannot hand back the type it was given:
	''
	''     string, zstring   ->  string       bytes, no encoding assumed
	''     wstring, ustring  ->  ustring      UTF-16 on every target
	''
	'' A WSTRING in therefore means a USTRING out. On Windows that costs
	'' nothing to use -- a ustring already IS UTF-16 -- and it is the only
	'' answer available, since a fixed-length result would need a buffer the
	'' caller has not supplied.
	'' =====================================================================

	'' Text BEFORE the first occurrence of `match` at or after `start`.
	''
	'' A MISS RETURNS THE WHOLE REMAINDER, not "". That is the PowerBASIC
	'' EXTRACT$ rule AfxStrExtract carries, and it is what makes a parse loop
	'' terminate cleanly: the final field has no trailing delimiter, and this
	'' hands it back instead of losing it. An empty `match` is a miss.
	''
	''     Extract( 1, "abacadabra", "cad" )    '' "aba"
	''     Extract( 1, "abacadabra", "zzz" )    '' "abacadabra"
	''
	'' Deliberately the opposite of Remain, whose miss is empty. The two are
	'' complements: everything before, and everything after.

	declare function Extract overload alias "fb_StrExtract" _
		( byval start as integer, byref s as const string, _
		  byref match as const ustring, byval ignoreCase as boolean = false ) as string

	declare function Extract overload alias "fb_WStrExtract" _
		( byval start as integer, byref s as const wstring, _
		  byref match as const ustring, byval ignoreCase as boolean = false ) as ustring

	declare function Extract overload alias "fb_UStrExtract" _
		( byval start as integer, byref s as const ustring, _
		  byref match as const ustring, byval ignoreCase as boolean = false ) as ustring

	'' Text before the first character that is in `chars`. Same miss rule.
	''     ExtractChars( 1, "abacadabra", "cd" )   '' "aba"

	declare function ExtractChars overload alias "fb_StrExtractChars" _
		( byval start as integer, byref s as const string, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as string

	declare function ExtractChars overload alias "fb_WStrExtractChars" _
		( byval start as integer, byref s as const wstring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as ustring

	declare function ExtractChars overload alias "fb_UStrExtractChars" _
		( byval start as integer, byref s as const ustring, _
		  byref chars as const ustring, byval ignoreCase as boolean = false ) as ustring

	'' Text AFTER the first occurrence of `match` at or after `start`.
	''
	'' A MISS RETURNS "". Nothing followed the thing that was not there, and
	'' returning the remainder would produce text that was never after
	'' anything. An empty `match` is a miss.
	''
	''     Remain( "Brevity is the soul of wit", "is " )  '' "the soul of wit"
	''     Remain( "Brevity is the soul of wit", "zzz" )  '' ""

	declare function Remain overload alias "fb_StrRemain" _
		( byref s as const string, byref match as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as string

	declare function Remain overload alias "fb_WStrRemain" _
		( byref s as const wstring, byref match as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	declare function Remain overload alias "fb_UStrRemain" _
		( byref s as const ustring, byref match as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	'' Text after the first character that is in `chars`. Same miss rule.

	declare function RemainChars overload alias "fb_StrRemainChars" _
		( byref s as const string, byref chars as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as string

	declare function RemainChars overload alias "fb_WStrRemainChars" _
		( byref s as const wstring, byref chars as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	declare function RemainChars overload alias "fb_UStrRemainChars" _
		( byref s as const ustring, byref chars as const ustring, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	'' Text between the first `open` at or after `start` and the first `close`
	'' AFTER that one. Either delimiter missing gives "" -- there is no
	'' "between" without both ends.
	''
	''     Between( "blah (text here) blah", "(", ")" )   '' "text here"
	''
	'' `close` is searched from the end of `open`, never from `start`, so
	'' Between( "(a)(b)", "(", ")" ) is "a" and cannot pair the first "(" with
	'' the second ")".

	declare function Between overload alias "fb_StrBetween" _
		( byref s as const string, byref opening as const ustring, _
		  byref closing as const ustring, byval start as integer = 1, _
		  byval ignoreCase as boolean = false ) as string

	declare function Between overload alias "fb_WStrBetween" _
		( byref s as const wstring, byref opening as const ustring, _
		  byref closing as const ustring, byval start as integer = 1, _
		  byval ignoreCase as boolean = false ) as ustring

	declare function Between overload alias "fb_UStrBetween" _
		( byref s as const ustring, byref opening as const ustring, _
		  byref closing as const ustring, byval start as integer = 1, _
		  byval ignoreCase as boolean = false ) as ustring

	'' ------------------------------------------------- slicing by position
	''
	'' A count of 0 or less removes nothing; a count at or past the length
	'' removes everything. Neither clamps into a negative length.
	''
	''     ClipLeft( "1234567890", 3 )     '' "4567890"
	''     ClipRight( "1234567890", 3 )    '' "1234567"

	declare function ClipLeft overload alias "fb_StrClipLeft" _
		( byref s as const string, byval count as integer ) as string

	declare function ClipLeft overload alias "fb_WStrClipLeft" _
		( byref s as const wstring, byval count as integer ) as ustring

	declare function ClipLeft overload alias "fb_UStrClipLeft" _
		( byref s as const ustring, byval count as integer ) as ustring

	declare function ClipRight overload alias "fb_StrClipRight" _
		( byref s as const string, byval count as integer ) as string

	declare function ClipRight overload alias "fb_WStrClipRight" _
		( byref s as const wstring, byval count as integer ) as ustring

	declare function ClipRight overload alias "fb_UStrClipRight" _
		( byref s as const ustring, byval count as integer ) as ustring

	'' `count` characters removed starting at the 1-based `start`.
	''
	''     DeleteAt( "1234567890", 4, 3 )   '' "1237890"
	''
	'' EVERY INVALID ARGUMENT IS A NO-OP returning the string unchanged --
	'' start below 1, start past the end, count of 0 or less. An out-of-range
	'' delete is not an error and never truncates. A count running past the
	'' end removes only what is there.
	''
	'' This is AfxNova's AfxStrDelete and AfxStrClipMid, which are the same
	'' algorithm under two names; one is enough.

	declare function DeleteAt overload alias "fb_StrDeleteAt" _
		( byref s as const string, byval start as integer, _
		  byval count as integer ) as string

	declare function DeleteAt overload alias "fb_WStrDeleteAt" _
		( byref s as const wstring, byval start as integer, _
		  byval count as integer ) as ustring

	declare function DeleteAt overload alias "fb_UStrDeleteAt" _
		( byref s as const ustring, byval start as integer, _
		  byval count as integer ) as ustring

	'' `insert` spliced in at the 1-based `position`.
	''
	''     InsertAt( "1234567890", "--", 6 )   '' "12345--67890"
	''
	'' A position PAST THE END APPENDS, which is the useful reading of
	'' "insert at position 20 of a 5-character string". A position BELOW 1
	'' does not insert at all and returns the string unchanged, matching
	'' DeleteAt's treatment of an invalid start.
	''
	'' (AfxStrInsert's comment says a position <= 0 appends; its code returns
	'' the string untouched. The code is followed here -- appending on a
	'' negative index is the kind of silent success that hides a caller's
	'' off-by-one.)

	declare function InsertAt overload alias "fb_StrInsertAt" _
		( byref s as const string, byref insert as const ustring, _
		  byval position as integer ) as string

	declare function InsertAt overload alias "fb_WStrInsertAt" _
		( byref s as const wstring, byref insert as const ustring, _
		  byval position as integer ) as ustring

	declare function InsertAt overload alias "fb_UStrInsertAt" _
		( byref s as const ustring, byref insert as const ustring, _
		  byval position as integer ) as ustring

	'' =====================================================================
	'' TRANSFORM -- building a new string from the old one
	''
	'' Same return rule as the extract family: string/zstring -> string,
	'' wstring/ustring -> ustring.
	'' =====================================================================

	'' Every NON-OVERLAPPING occurrence of `match` becomes `with`.
	''
	''     Replace( "Hello World", "World", "Earth" )   '' "Hello Earth"
	''
	'' SINGLE PASS. The scan continues after each replacement and never
	'' re-reads what was just written, so a replacement that contains the
	'' pattern neither cascades nor loops:
	''
	''     Replace( "a", "a", "aa" )     '' "aa", not a hang
	''
	'' An empty `match` matches nothing and copies the input through.

	declare function Replace overload alias "fb_StrReplace" _
		( byref s as const string, byref match as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as string

	declare function Replace overload alias "fb_WStrReplace" _
		( byref s as const wstring, byref match as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as ustring

	declare function Replace overload alias "fb_UStrReplace" _
		( byref s as const ustring, byref match as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as ustring

	'' Every occurrence of `match` deleted. EXACTLY Replace with an empty
	'' replacement, and that equivalence is the point.
	''
	'' AfxStrRemove restarts its search from position 1 after each deletion,
	'' so removals CASCADE -- deleting "ab" from "aabb" leaves "" there,
	'' because the deletion creates a new match that did not exist in the
	'' input. Here it leaves "ab". A single pass is what Replace does, it is
	'' what the documentation of both implies, and it is O(n) rather than
	'' O(n^2). Deliberate divergence.

	declare function Remove overload alias "fb_StrRemove" _
		( byref s as const string, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as string

	declare function Remove overload alias "fb_WStrRemove" _
		( byref s as const wstring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	declare function Remove overload alias "fb_UStrRemove" _
		( byref s as const ustring, byref match as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	'' Every character that is in `chars` deleted. An empty set deletes
	'' nothing.
	''     RemoveChars( "abacadabra", "bac" )     '' "dr"

	declare function RemoveChars overload alias "fb_StrRemoveChars" _
		( byref s as const string, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as string

	declare function RemoveChars overload alias "fb_WStrRemoveChars" _
		( byref s as const wstring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	declare function RemoveChars overload alias "fb_UStrRemoveChars" _
		( byref s as const ustring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	'' Only the characters that are in `chars` kept -- the complement of
	'' RemoveChars. An empty set keeps nothing, which is that complement.
	''     RetainChars( "abacadabra", "bc" )      '' "bcb"

	declare function RetainChars overload alias "fb_StrRetainChars" _
		( byref s as const string, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as string

	declare function RetainChars overload alias "fb_WStrRetainChars" _
		( byref s as const wstring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	declare function RetainChars overload alias "fb_UStrRetainChars" _
		( byref s as const ustring, byref chars as const ustring, _
		  byval ignoreCase as boolean = false ) as ustring

	'' Every character in `chars` mapped to `with_`.
	''
	''     ReplaceChars( "abacadabra", "bac", "*" )   '' "*****d**r*"
	''
	'' THE LENGTH NEVER CHANGES -- one unit for one unit, so positions into
	'' the result still line up with the input. `with_` must therefore be
	'' EXACTLY ONE unit: anything else (empty, longer, or an astral character,
	'' which is two units) has no one-for-one form and the call returns the
	'' string unchanged rather than guessing.
	''
	'' On the BYTE family a unit is a byte, so a non-ASCII `with_` is a UTF-8
	'' lead byte rather than a character and is rejected on the same rule. Use
	'' the ustring overload for non-ASCII substitution.

	declare function ReplaceChars overload alias "fb_StrReplaceChars" _
		( byref s as const string, byref chars as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as string

	declare function ReplaceChars overload alias "fb_WStrReplaceChars" _
		( byref s as const wstring, byref chars as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as ustring

	declare function ReplaceChars overload alias "fb_UStrReplaceChars" _
		( byref s as const ustring, byref chars as const ustring, _
		  byref with_ as const ustring, byval ignoreCase as boolean = false ) as ustring

	'' From each `opening` through the matching `closing`, delimiters
	'' included, deleted. `removeAll` repeats until no pair is left.
	''
	''     RemoveBetween( "blah (text) blah", "(", ")" )
	''         '' "blah  blah"
	''     RemoveBetween( "var1(34), var2( 73 ), var3(any)", "(", ")", true )
	''         '' "var1, var2, var3"
	''
	'' An unbalanced opener stops the walk and leaves the rest alone, so a
	'' stray "(" does not swallow the tail. `closing` is searched from the end
	'' of `opening`, so a pair cannot be crossed.

	declare function RemoveBetween overload alias "fb_StrRemoveBetween" _
		( byref s as const string, byref opening as const ustring, _
		  byref closing as const ustring, byval removeAll as boolean = false, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as string

	declare function RemoveBetween overload alias "fb_WStrRemoveBetween" _
		( byref s as const wstring, byref opening as const ustring, _
		  byref closing as const ustring, byval removeAll as boolean = false, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	declare function RemoveBetween overload alias "fb_UStrRemoveBetween" _
		( byref s as const ustring, byref opening as const ustring, _
		  byref closing as const ustring, byval removeAll as boolean = false, _
		  byval start as integer = 1, byval ignoreCase as boolean = false ) as ustring

	'' Reversed.
	''
	'' SURROGATE PAIRS SURVIVE ON THE WIDE FAMILY AND NOT ON THE BYTE ONE,
	'' which is the one place these two deliberately differ.
	''
	'' A ustring is UTF-16 by definition, so reversing its code units blindly
	'' would emit a low surrogate before its high one -- invalid UTF-16 every
	'' time an astral character is present, not occasionally. AfxStrReverse
	'' does exactly that. Here the pair is kept together.
	''
	'' A STRING is bytes with no declared encoding, so there is no pair to
	'' recognise; bytes reverse as bytes. That does mangle multi-byte UTF-8,
	'' and it is the only defensible answer for a type that does not say what
	'' it holds. Reverse UTF-8 text through the ustring overload.

	declare function Reverse overload alias "fb_StrReverse" _
		( byref s as const string ) as string

	declare function Reverse overload alias "fb_WStrReverse" _
		( byref s as const wstring ) as ustring

	declare function Reverse overload alias "fb_UStrReverse" _
		( byref s as const ustring ) as ustring

	'' `count` copies joined. A count of 0 or less gives "".
	''     Repeat( 3, "ab" )      '' "ababab"
	''
	'' STRING( n, ch ) already repeats a single character; this repeats a
	'' whole string, in one allocation rather than n concatenations.

	declare function Repeat overload alias "fb_StrRepeat" _
		( byval count as integer, byref s as const string ) as string

	declare function Repeat overload alias "fb_WStrRepeat" _
		( byval count as integer, byref s as const wstring ) as ustring

	declare function Repeat overload alias "fb_UStrRepeat" _
		( byval count as integer, byref s as const ustring ) as ustring

	'' Runs of `mask` characters collapsed to one, and stripped from both
	'' ends. The result is words separated by exactly one mask(1).
	''
	''     Shrink( ",,, one , two     three, four,", " ," )
	''         '' "one two three four"
	''
	'' An EMPTY mask returns the input unchanged -- there is nothing to
	'' shrink. (AfxStrShrink returns the EMPTY STRING for an empty mask, which
	'' reads like a guard clause that fell through to the wrong variable.)
	''
	'' No ignoreCase: a mask is a set of delimiters, and a delimiter whose
	'' case matters is not a delimiter.

	declare function Shrink overload alias "fb_StrShrink" _
		( byref s as const string, byref mask as const ustring = " " ) as string

	declare function Shrink overload alias "fb_WStrShrink" _
		( byref s as const wstring, byref mask as const ustring = " " ) as ustring

	declare function Shrink overload alias "fb_UStrShrink" _
		( byref s as const ustring, byref mask as const ustring = " " ) as ustring

	'' Title case: the first letter of each word upper, the rest lower.
	''     MCase( "hello wide world" )    '' "Hello Wide World"
	''
	'' A WORD STARTS after any character that is not alphanumeric. AfxNova's
	'' DWStrMCase tests against a fixed list of punctuation instead, so it
	'' capitalises after "." and "-" but not after "/", "_" or a tab -- gaps
	'' rather than decisions. "Not alphanumeric" needs no list.
	''
	'' Non-ASCII counts as a word character: an accented letter continues a
	'' word, and a character with no case mapping is left as it is.

	declare function MCase overload alias "fb_StrMCase" _
		( byref s as const string ) as string

	declare function MCase overload alias "fb_WStrMCase" _
		( byref s as const wstring ) as ustring

	declare function MCase overload alias "fb_UStrMCase" _
		( byref s as const ustring ) as ustring

	'' =====================================================================
	'' PAD, WRAP, ESCAPE, PREDICATES
	'' =====================================================================

	'' Justified into a field of exactly `width`, padded with `pad`.
	''
	''     PadRight( "FreeBasic", 12, "*" )    '' "FreeBasic***"
	''     PadLeft ( "FreeBasic", 12, "*" )    '' "***FreeBasic"
	''     PadCenter("FreeBasic", 13, "*" )    '' "**FreeBasic**"
	''
	'' THE RESULT IS ALWAYS EXACTLY `width`. A string longer than the field is
	'' TRUNCATED, keeping its left -- that is what makes a column line up
	'' whatever is in it, and it is what all three AfxNova pad functions do.
	'' A width of 0 or less gives "".
	''
	'' PadCenter puts the odd unit on the RIGHT: one character in a field of
	'' four gets one pad before and two after. Integer division decides it, so
	'' it is written down rather than left to be found out.
	''
	'' `pad` is ONE character. Anything else -- empty, longer, or an astral
	'' character, which is two code units -- pads with a SPACE instead, rather
	'' than writing half a character. On the byte family a unit is a byte, so
	'' a non-ASCII pad is a UTF-8 lead byte and falls back the same way.

	declare function PadRight overload alias "fb_StrPadRight" _
		( byref s as const string, byval width as integer, _
		  byref pad as const ustring = " " ) as string

	declare function PadRight overload alias "fb_WStrPadRight" _
		( byref s as const wstring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	declare function PadRight overload alias "fb_UStrPadRight" _
		( byref s as const ustring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	declare function PadLeft overload alias "fb_StrPadLeft" _
		( byref s as const string, byval width as integer, _
		  byref pad as const ustring = " " ) as string

	declare function PadLeft overload alias "fb_WStrPadLeft" _
		( byref s as const wstring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	declare function PadLeft overload alias "fb_UStrPadLeft" _
		( byref s as const ustring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	declare function PadCenter overload alias "fb_StrPadCenter" _
		( byref s as const string, byval width as integer, _
		  byref pad as const ustring = " " ) as string

	declare function PadCenter overload alias "fb_WStrPadCenter" _
		( byref s as const wstring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	declare function PadCenter overload alias "fb_UStrPadCenter" _
		( byref s as const ustring, byval width as integer, _
		  byref pad as const ustring = " " ) as ustring

	'' ------------------------------------------------------- wrap/unwrap
	''
	'' AN EMPTY `closing` MEANS "THE SAME AS `opening`". That one rule covers
	'' all three AfxNova forms with a single function:
	''
	''     Wrap( "Paul" )              '' "Paul" in double quotes
	''     Wrap( "Paul", "'" )         '' 'Paul'
	''     Wrap( "Paul", "<", ">" )    '' <Paul>
	''
	'' A genuinely one-sided wrap is InsertAt's job.

	declare function Wrap overload alias "fb_StrWrap" _
		( byref s as const string, byref opening as const ustring = """", _
		  byref closing as const ustring = "" ) as string

	declare function Wrap overload alias "fb_WStrWrap" _
		( byref s as const wstring, byref opening as const ustring = """", _
		  byref closing as const ustring = "" ) as ustring

	declare function Wrap overload alias "fb_UStrWrap" _
		( byref s as const ustring, byref opening as const ustring = """", _
		  byref closing as const ustring = "" ) as ustring

	'' The inverse: ONE leading `opening` and ONE trailing `closing` removed,
	'' AND ONLY IF BOTH ARE PRESENT and do not overlap.
	''
	''     Unwrap( "<Paul>", "<", ">" )   '' "Paul"
	''     Unwrap( "<Paul",  "<", ">" )   '' "<Paul"  -- unbalanced, untouched
	''     Unwrap( "''x''", "'" )         '' "'x'"    -- one pair, not all
	''
	'' AfxStrUnWrap uses LTRIM/RTRIM with the delimiter, so it strips REPEATED
	'' occurrences and does not require a pair -- "'''x'''" loses all six
	'' quotes and "'x" loses its opener with nothing matching it. Stripping a
	'' delimiter that was never balanced is how a quoted field containing a
	'' quote gets silently mangled. Deliberate divergence.

	declare function Unwrap overload alias "fb_StrUnwrap" _
		( byref s as const string, byref opening as const ustring = """", _
		  byref closing as const ustring = "", _
		  byval ignoreCase as boolean = false ) as string

	declare function Unwrap overload alias "fb_WStrUnwrap" _
		( byref s as const wstring, byref opening as const ustring = """", _
		  byref closing as const ustring = "", _
		  byval ignoreCase as boolean = false ) as ustring

	declare function Unwrap overload alias "fb_UStrUnwrap" _
		( byref s as const ustring, byref opening as const ustring = """", _
		  byref closing as const ustring = "", _
		  byval ignoreCase as boolean = false ) as ustring

	'' --------------------------------------------------- escape/unescape
	''
	'' Backslash escaping -- what makes a string safe to write between quotes
	'' in a config file, a log line or generated source, and reversible after.
	''
	''     \  "            ->  \\  \"
	''     LF CR TAB NUL   ->  \n  \r  \t  \0
	''     other units below 32, and 127  ->  \xHH
	''     everything else, INCLUDING ALL NON-ASCII, passes through
	''
	'' Non-ASCII is left alone on purpose: escaping it would make a ustring
	'' unreadable and reduce a UTF-8 STRING to a wall of hex, and the job here
	'' is to neutralise what breaks quoting, not to force the text to ASCII.
	''
	'' UNESCAPE IS THE EXACT INVERSE. Unescape( Escape( s ) ) = s for every
	'' input, including one that already contains backslashes. An unrecognised
	'' escape yields the escaped character ("\q" -> "q"); a trailing lone
	'' backslash is kept, since there is nothing after it to unquote.
	''
	'' NOT AfxNova's DWStrEscape, which escapes REGULAR EXPRESSION
	'' metacharacters so a literal can be used as a pattern. That is only
	'' meaningful beside a regex engine -- it is built on CRegExp, a COM class
	'' -- and there is no regex engine here, so it is not carried across.

	declare function Escape overload alias "fb_StrEscape" _
		( byref s as const string ) as string

	declare function Escape overload alias "fb_WStrEscape" _
		( byref s as const wstring ) as ustring

	declare function Escape overload alias "fb_UStrEscape" _
		( byref s as const ustring ) as ustring

	declare function Unescape overload alias "fb_StrUnescape" _
		( byref s as const string ) as string

	declare function Unescape overload alias "fb_WStrUnescape" _
		( byref s as const wstring ) as ustring

	declare function Unescape overload alias "fb_UStrUnescape" _
		( byref s as const ustring ) as ustring

	'' ----------------------------------------------------------- predicates

	'' Does the WHOLE string parse as a decimal number?
	''
	''     [ws] [+|-] ( digits [ . [digits] ] | . digits )
	''          [ (e|E|d|D) [+|-] digits ] [ws]
	''
	'' At least one digit is required, and trailing junk fails -- "", "+", ".",
	'' "e5" and "12abc" are all false; " -1.5e+3 " is true.
	''
	'' A DIFFERENT FUNCTION FROM AfxIsNumeric, not a port of it. That one asks
	'' whether every character is drawn from "+-.0123456789", which makes
	'' "++--.." numeric -- it is a character-set test, and RetainChars already
	'' does those, better. A predicate called IsNumeric should answer whether
	'' the thing is a number.
	''
	'' Radix literals (&H, &O, &B) are NOT accepted. VAL does take them, but
	'' they are FreeBASIC literal syntax rather than numeric text.

	declare function IsNumeric overload alias "fb_StrIsNumeric" _
		( byref s as const string ) as boolean

	declare function IsNumeric overload alias "fb_WStrIsNumeric" _
		( byref s as const wstring ) as boolean

	declare function IsNumeric overload alias "fb_UStrIsNumeric" _
		( byref s as const ustring ) as boolean

	'' Empty, or nothing but whitespace -- space, tab, LF, VT, FF, CR. The set
	'' is spelled out rather than taken from isspace(), so it does not shift
	'' with the locale.

	declare function IsBlank overload alias "fb_StrIsBlank" _
		( byref s as const string ) as boolean

	declare function IsBlank overload alias "fb_WStrIsBlank" _
		( byref s as const wstring ) as boolean

	declare function IsBlank overload alias "fb_UStrIsBlank" _
		( byref s as const ustring ) as boolean

end extern

	'' The split boundary helpers. Internal: they return a field count and
	'' write (offset, length) pairs, and the Split bodies below are the only
	'' callers. Kept in a nested namespace so `using FB` does not put them
	'' next to the functions people actually call.
	''
	'' Its own extern "C", because a nested namespace does NOT inherit the
	'' enclosing one -- without it `alias` is still mangled and the symbol comes
	'' out as FB::Detail::fb_StrSplitSpans(...), which does not link.
	namespace Detail
	FBSTR_EXTERN

		declare function SplitSpans overload alias "fb_StrSplitSpans" _
			( byref s as const string, byref delim as const ustring, _
			  byval ignoreCase as boolean, byval outp as integer ptr, _
			  byval maxpairs as integer ) as integer

		declare function SplitSpans overload alias "fb_UStrSplitSpans" _
			( byref s as const ustring, byref delim as const ustring, _
			  byval ignoreCase as boolean, byval outp as integer ptr, _
			  byval maxpairs as integer ) as integer

		declare function SplitCharsSpans overload alias "fb_StrSplitCharsSpans" _
			( byref s as const string, byref chars as const ustring, _
			  byval ignoreCase as boolean, byval outp as integer ptr, _
			  byval maxpairs as integer ) as integer

		declare function SplitCharsSpans overload alias "fb_UStrSplitCharsSpans" _
			( byref s as const ustring, byref chars as const ustring, _
			  byval ignoreCase as boolean, byval outp as integer ptr, _
			  byval maxpairs as integer ) as integer

	end extern
	end namespace

'' =========================================================================
'' SPLIT and JOIN
''
'' The only functions here with FreeBASIC bodies rather than declarations,
'' because their result is an Array( of T ) -- a language-level construct the
'' runtime cannot build.
''
'' They are PRIVATE, so each module that includes this header gets its own
'' copy and two modules including it still link. That is the same trade the
'' generic containers already make (one instantiation per module): a little
'' size, no linkage problem.
''
'' THE FIELD COUNT IS ALWAYS AT LEAST 1. An empty string is one empty field,
'' and so is a string with no delimiter in it. N delimiters give N+1 fields,
'' always, so no field is ever silently dropped:
''
''     Split( "a,b,c" )   -> 3   "a" "b" "c"
''     Split( "a,,c" )    -> 3   "a" ""  "c"
''     Split( ",a" )      -> 2   ""  "a"
''     Split( "a," )      -> 2   "a" ""
''     Split( "" )        -> 1   ""
''
'' That is AfxStrParseCount's rule, and it is the one that makes a round trip
'' work: Join( Split( s ) ) is s for every s.
''
'' An empty delimiter splits nothing and yields the whole input as one field,
'' consistent with every other function here treating an empty pattern as
'' matching nothing.
''
'' COMPLEXITY. Two linear passes -- one to count, one to fill -- not the
'' ParseCount-then-Parse-in-a-loop shape, which rescans from the start for
'' every field and is O(n^2).
''
'' Still inside NAMESPACE FB, which the extern "C" block above sat within --
'' these are FreeBASIC procedures, so they must not carry C linkage.
'' =========================================================================

	private function Split overload _
		( byref s as const string, byref delim as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of string )

		dim res as Array( of string )

		dim as integer n = Detail.SplitSpans( s, delim, ignoreCase, 0, 0 )
		if n <= 0 then return res

		dim as integer spans( 0 to n * 2 - 1 )
		Detail.SplitSpans( s, delim, ignoreCase, @spans( 0 ), n )

		res.Reserve( n )
		for i as integer = 0 to n - 1
			dim as string piece = mid( s, spans( i * 2 ) + 1, spans( i * 2 + 1 ) )
			res.Push( piece )
		next

		return res
	end function

	private function Split overload _
		( byref s as const ustring, byref delim as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of ustring )

		dim res as Array( of ustring )

		dim as integer n = Detail.SplitSpans( s, delim, ignoreCase, 0, 0 )
		if n <= 0 then return res

		dim as integer spans( 0 to n * 2 - 1 )
		Detail.SplitSpans( s, delim, ignoreCase, @spans( 0 ), n )

		res.Reserve( n )
		for i as integer = 0 to n - 1
			dim as ustring piece = mid( s, spans( i * 2 ) + 1, spans( i * 2 + 1 ) )
			res.Push( piece )
		next

		return res
	end function

	'' A WSTRING yields an Array( of ustring ), following the return rule for
	'' every other function here. Converted once and handed to the ustring
	'' body rather than given a second boundary path of its own.
	private function Split overload _
		( byref s as const wstring, byref delim as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of ustring )

		dim as ustring tmp = s
		return Split( tmp, delim, ignoreCase )
	end function

	'' Every character in `chars` is a separator in its own right.
	''     SplitChars( "a,b;c", ",;" )    -> 3   "a" "b" "c"

	private function SplitChars overload _
		( byref s as const string, byref chars as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of string )

		dim res as Array( of string )

		dim as integer n = Detail.SplitCharsSpans( s, chars, ignoreCase, 0, 0 )
		if n <= 0 then return res

		dim as integer spans( 0 to n * 2 - 1 )
		Detail.SplitCharsSpans( s, chars, ignoreCase, @spans( 0 ), n )

		res.Reserve( n )
		for i as integer = 0 to n - 1
			dim as string piece = mid( s, spans( i * 2 ) + 1, spans( i * 2 + 1 ) )
			res.Push( piece )
		next

		return res
	end function

	private function SplitChars overload _
		( byref s as const ustring, byref chars as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of ustring )

		dim res as Array( of ustring )

		dim as integer n = Detail.SplitCharsSpans( s, chars, ignoreCase, 0, 0 )
		if n <= 0 then return res

		dim as integer spans( 0 to n * 2 - 1 )
		Detail.SplitCharsSpans( s, chars, ignoreCase, @spans( 0 ), n )

		res.Reserve( n )
		for i as integer = 0 to n - 1
			dim as ustring piece = mid( s, spans( i * 2 ) + 1, spans( i * 2 + 1 ) )
			res.Push( piece )
		next

		return res
	end function

	private function SplitChars overload _
		( byref s as const wstring, byref chars as const ustring = ",", _
		  byval ignoreCase as boolean = false ) as Array( of ustring )

		dim as ustring tmp = s
		return SplitChars( tmp, chars, ignoreCase )
	end function

	'' -------------------------------------------------------------- Join
	''
	'' The inverse of Split. An empty array gives "", one element gives that
	'' element, and no separator is added before the first or after the last.
	''
	''     Join( Split( s, d ), d ) = s     for every s and every non-empty d
	''
	'' Sized in one pass and filled with MID, so it is LINEAR. Repeated `&=`
	'' would be O(n^2): FreeBASIC strings do not over-allocate, so every
	'' append reallocates and copies everything written so far.
	''
	'' `parts` is BYREF and not const because Array's indexer is not const --
	'' passing it byval would deep-copy the whole array to read it.

	private function Join overload _
		( byref parts as Array( of string ), byref delim as const ustring = "," ) as string

		dim as integer n = parts.Count( )
		if n <= 0 then return ""

		dim as string d = delim
		dim as integer total = ( n - 1 ) * len( d )
		for i as integer = 0 to n - 1
			total += len( parts[ i ] )
		next

		if total <= 0 then return ""

		dim as string res = space( total )
		dim as integer at = 1

		for i as integer = 0 to n - 1
			if i > 0 andalso len( d ) > 0 then
				mid( res, at, len( d ) ) = d
				at += len( d )
			end if
			dim as integer pl = len( parts[ i ] )
			if pl > 0 then
				mid( res, at, pl ) = parts[ i ]
				at += pl
			end if
		next

		return res
	end function

	private function Join overload _
		( byref parts as Array( of ustring ), byref delim as const ustring = "," ) as ustring

		dim as integer n = parts.Count( )
		if n <= 0 then return ""

		dim as integer total = ( n - 1 ) * len( delim )
		for i as integer = 0 to n - 1
			total += len( parts[ i ] )
		next

		if total <= 0 then return ""

		'' a ustring of `total` spaces -- SPACE() would give a STRING
		dim as ustring one = " "
		dim as ustring res = Repeat( total, one )
		dim as integer at = 1

		for i as integer = 0 to n - 1
			if i > 0 andalso len( delim ) > 0 then
				mid( res, at, len( delim ) ) = delim
				at += len( delim )
			end if
			dim as integer pl = len( parts[ i ] )
			if pl > 0 then
				mid( res, at, pl ) = parts[ i ]
				at += pl
			end if
		next

		return res
	end function

end namespace
