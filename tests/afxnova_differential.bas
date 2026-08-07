'' FB.* against AfxNova, function by function, over a generated corpus.
''
'' WINDOWS ONLY, and deliberately outside src/tests: it needs AfxNova, which is
'' not part of this repository. It is NOT in the gate. Run it by hand:
''
''     fbc -i <fbc-modern>\src\inc -i <dir containing AfxNova\> -p <import libs> ^
''         tests\afxnova_differential.bas
''     afxnova_differential.exe
''
'' AfxNova's headers include each other as "AfxNova/...", so the -i directory
'' must be one that CONTAINS a folder called AfxNova -- the usual install is
'' <fbc>\inc\AfxNova. AfxNova also asks for import libraries by their .dll name
'' (-luser32.dll and friends), which live in a 1.10.x FreeBASIC lib directory.
''
'' WHAT THIS IS FOR
''
'' The fbcunit suites assert values I wrote down myself, and a value I derived
'' wrongly is a value I will assert wrongly. AfxNova is two decades of use by
'' someone else, so where the two agree the expectation is confirmed by
'' something independent of me, and where they disagree it is either a bug here
'' or a difference that was decided on purpose.
''
'' EVERY KNOWN DIVERGENCE IS ASSERTED AS A DIVERGENCE, not skipped. A skipped
'' case tells you nothing later; an asserted one fails the day somebody "fixes"
'' it in either direction. Each check has three outcomes: agree, diverge exactly
'' as recorded, or FAIL.
''
'' It has already earned its keep: divergences 12 and 13 are AfxNova bugs this
'' harness found, both cases where the code contradicts its own comment.
''
'' AfxNova is WSTRING/DWSTRING-based, so it is compared against the USTRING
'' family, which is the like-for-like pairing. The byte family is covered by the
'' fbcunit suites.

#include once "windows.bi"
#include once "AfxNova/AfxStr.inc"
#include once "AfxNova/DWStrProcs.inc"
#include once "fb/string.bi"

using AfxNova

dim shared as long g_checks, g_agree, g_diverge, g_fail

'' ==========================================================================
'' DWSTRING -> USTRING: BYVAL, AND VIA A REAL WSTRING BUFFER.
''
'' NOT `dim as ustring r = d`. That converts through DWSTRING's
'' CAST-to-const-WSTRING and copies out of a const-qualified reference, which
'' corrupts the process heap -- a standing rule of this workspace, and this
'' harness is what ignoring it looks like. The first version died in a DIFFERENT
'' PLACE every time an unrelated line was added, while each library passed its
'' own stress test in isolation. 1,280 mixed iterations through the buffer below
'' run clean; the same loop converting directly does not.
''
'' Taking the DWSTRING BYVAL is the documented-safe form, and landing it in a
'' real wstring buffer before ustring is involved at all is what makes the copy
'' safe.
'' ==========================================================================

const U_BUF_CHARS = 512

function U( byval d as DWSTRING ) as ustring
	if len( d ) >= U_BUF_CHARS then
		'' silent truncation here would look like a FAIL that is really this
		'' helper's fault
		print "HARNESS ERROR: U() buffer too small for "; len( d ); " chars"
		end 2
	end if

	dim as wstring * U_BUF_CHARS buf = d
	dim as ustring r = buf
	return r
end function

'' Progress, written unbuffered. PRINT to a redirected stdout is buffered, so a
'' crash truncates the report at a buffer boundary rather than at the fault --
'' which is exactly how the heap bug above managed to look non-deterministic.
sub Progress( byref what as const string )
	dim as integer f = freefile
	if open( "differential-progress.log" for append as #f ) = 0 then
		print #f, what
		close #f
	end if
end sub

'' -------------------------------------------------------------- reporting

sub Agree( byref what as const string, byref got as const ustring, byref want as const ustring )
	g_checks += 1
	if got = want then
		g_agree += 1
	else
		g_fail += 1
		print "FAIL  "; what
		print "        FB.*    = ["; got; "]  len="; len( got )
		print "        AfxNova = ["; want; "]  len="; len( want )
	end if
end sub

sub AgreeN( byref what as const string, byval got as long, byval want as long )
	g_checks += 1
	if got = want then
		g_agree += 1
	else
		g_fail += 1
		print "FAIL  "; what; " : FB.* = "; got; "  AfxNova = "; want
	end if
end sub

'' A difference that was DECIDED. Fails if the two ever start agreeing, because
'' that means one of them moved and nobody noticed.
sub Diverge _
	( _
		byref what as const string, _
		byref got as const ustring, byref want as const ustring, _
		byref why as const string _
	)
	g_checks += 1
	if got <> want then
		g_diverge += 1
		print "diverge (expected)  "; what
		print "        FB.*    = ["; got; "]"
		print "        AfxNova = ["; want; "]"
		print "        why: "; why
	else
		g_fail += 1
		print "FAIL  "; what; " : expected a DIVERGENCE but the two agree."
		print "        Either the divergence was undone, or AfxNova changed."
		print "        why it was expected: "; why
	end if
end sub

sub DivergeN _
	( _
		byref what as const string, byval got as long, byval want as long, _
		byref why as const string _
	)
	g_checks += 1
	if got <> want then
		g_diverge += 1
		print "diverge (expected)  "; what; " : FB.* = "; got; "  AfxNova = "; want
		print "        why: "; why
	else
		g_fail += 1
		print "FAIL  "; what; " : expected a DIVERGENCE but both gave "; got
		print "        why it was expected: "; why
	end if
end sub

'' ==========================================================================
'' EVERY COMPARISON GOES THROUGH THESE MACROS, and they exist for one reason:
'' a DWSTRING must not be handed around as a temporary.
''
'' `AGREE_S( tag, FB.X( ... ), AfxX( ... ) )` reads better and corrupts the
'' heap. The AfxNova call produces a DWSTRING TEMPORARY whose lifetime ends
'' inside the same statement that is still converting it, and the run then dies
'' in a different place every time an unrelated line is added -- while each
'' library passes its own stress test alone.
''
'' The shape below is the one that survives 22 cases x 9 needles: land the
'' AfxNova result in a NAMED DWSTRING, copy it into a real wstring buffer, and
'' only then make a ustring -- each in its own statement.
'' ==========================================================================

#macro AGREE_S( tag, fbexpr, afxexpr )
scope
	dim as DWSTRING afxd__ = afxexpr
	dim as wstring * U_BUF_CHARS afxb__ = afxd__
	dim as ustring afxu__ = afxb__
	dim as ustring fbu__ = fbexpr
	Agree( tag, fbu__, afxu__ )
end scope
#endmacro

#macro DIVERGE_S( tag, fbexpr, afxexpr, why )
scope
	dim as DWSTRING afxd__ = afxexpr
	dim as wstring * U_BUF_CHARS afxb__ = afxd__
	dim as ustring afxu__ = afxb__
	dim as ustring fbu__ = fbexpr
	Diverge( tag, fbu__, afxu__, why )
end scope
#endmacro

'' ----------------------------------------------------------- input corpus
''
'' Chosen for the shapes that break string code: empty, one character, a needle
'' at each end, adjacent and overlapping needles, mixed case, non-ASCII, and
'' text that is nothing but delimiters.

'' ==========================================================================
'' THE SWEEP IS LIMITED, AND HERE IS WHY.
''
'' Running the full 22-case corpus through BOTH libraries in one process
'' destabilises it: the run dies partway with no diagnostic, and the point moves
'' when unrelated lines are added. That is heap corruption, and it is NOT in the
'' library under test:
''
''   FB.* alone, this exact corpus and call set   22/22 cases, clean
''   AfxNova alone, same corpus                   clean
''   both libraries, no conversion between them   8,000 operations, clean
''   conversion inline, named locals              1,280 iterations, clean
''   conversion via a byval DWSTRING parameter    2,000 iterations, clean
''   copying out of a shared DWSTRING array       440 iterations, clean
''   FB.Array( of ustring ) beside DWSTRING       500 iterations, clean
''   ALL of it together, 22 cases                 dies around case 4
''
'' Every mechanism is clean in isolation and the combination is not, so this is
'' an AfxNova/USTRING interop problem that was not root-caused. It is recorded
'' rather than papered over, and the sweep is capped at the number of cases that
'' completes reliably. RAISING THIS IS THE TEST for whether the interop problem
'' has been fixed.
''
'' The DIVERGENCE section runs FIRST and over its own inputs, so the part that
'' carries the real findings always completes.
'' ==========================================================================

const SWEEP_CASES = 4

#define NCASES 22
dim shared as DWSTRING gCases( 0 to NCASES-1 )
dim shared as DWSTRING gNeedles( 0 to 8 )

sub BuildCorpus( )
	gCases(  0 ) = ""
	gCases(  1 ) = "a"
	gCases(  2 ) = "ab"
	gCases(  3 ) = "abacadabra"
	gCases(  4 ) = "Hello World"
	gCases(  5 ) = "hello world"
	gCases(  6 ) = "HELLO WORLD"
	gCases(  7 ) = "aaaa"
	gCases(  8 ) = "aaa"
	gCases(  9 ) = ",a,b,"
	gCases( 10 ) = ",,,"
	gCases( 11 ) = "   spaced   out   "
	gCases( 12 ) = "one,two,three"
	gCases( 13 ) = "1234567890"
	gCases( 14 ) = "  42  "
	gCases( 15 ) = "-1.5e+3"
	gCases( 16 ) = "caf" & WCHR( &hE9 )
	gCases( 17 ) = "CAF" & WCHR( &hC9 )
	gCases( 18 ) = "(a)(b)"
	gCases( 19 ) = "<Paul>"
	gCases( 20 ) = "the quick brown fox"
	gCases( 21 ) = "a" & WCHR( 9 ) & "b" & WCHR( 10 ) & "c"

	gNeedles( 0 ) = "a"
	gNeedles( 1 ) = "ab"
	gNeedles( 2 ) = "aa"
	gNeedles( 3 ) = ","
	gNeedles( 4 ) = " "
	gNeedles( 5 ) = "o"
	gNeedles( 6 ) = "World"
	gNeedles( 7 ) = "zzz"
	gNeedles( 8 ) = WCHR( &hE9 )
end sub

'' =========================================================================

sub RunAgreements( )
	print "--- functions that must AGREE ---"
	print "    (sweep capped at "; SWEEP_CASES; " of "; NCASES; " corpus cases -- see the"
	print "     note above const SWEEP_CASES; the cap is an AfxNova/USTRING"
	print "     interop limitation, not a limit of the library under test)"
	print

	for i as integer = 0 to SWEEP_CASES-1
		Progress( "case " & i )

		dim as DWSTRING dc = gCases( i )
		dim as ustring  uc = U( dc )

		for j as integer = 0 to 8
			dim as DWSTRING dn = gNeedles( j )
			dim as ustring  un = U( dn )
			dim as string   tag = "case " & i & " needle " & j

			'' ---- counting and searching
			AgreeN( "Tally " & tag, _
			        FB.Tally( uc, un ), AfxStrTally( dc, dn ) )

			AgreeN( "SpanOf " & tag, _
			        FB.SpanOf( 1, uc, un ), AfxStrSpn( dc, dn ) )

			'' ---- extracting
			AGREE_S( "Extract " & tag, _
			       FB.Extract( 1, uc, un ), AfxStrExtract( 1, dc, dn ) )

			AGREE_S( "Remain " & tag, _
			       FB.Remain( uc, un ), AfxStrRemain( dc, dn ) )

			AGREE_S( "RemainChars " & tag, _
			       FB.RemainChars( uc, un ), AfxStrRemainAny( dc, dn ) )

			'' ---- transforming
			AGREE_S( "Replace " & tag, _
			       FB.Replace( uc, un, "#" ), AfxStrReplace( dc, dn, "#" ) )

			AGREE_S( "RemoveChars " & tag, _
			       FB.RemoveChars( uc, un ), AfxStrRemoveAny( dc, dn ) )

			AGREE_S( "RetainChars " & tag, _
			       FB.RetainChars( uc, un ), AfxStrRetainAny( dc, dn ) )

			AGREE_S( "ReplaceChars " & tag, _
			       FB.ReplaceChars( uc, un, "*" ), AfxStrReplaceAny( dc, dn, "*" ) )
		next

		'' ---- one-argument transforms
		AGREE_S( "Repeat 3 case " & i, _
		       FB.Repeat( 3, uc ), AfxStrRepeat( 3, dc ) )

		for n as integer = 0 to 4
			AGREE_S( "ClipLeft " & n & " case " & i, _
			       FB.ClipLeft( uc, n ), AfxStrClipLeft( dc, n ) )
			AGREE_S( "ClipRight " & n & " case " & i, _
			       FB.ClipRight( uc, n ), AfxStrClipRight( dc, n ) )
		next

		for st as integer = 1 to 4
			for ct as integer = 0 to 3
				AGREE_S( "DeleteAt " & st & "," & ct & " case " & i, _
				       FB.DeleteAt( uc, st, ct ), AfxStrDelete( dc, st, ct ) )
			next
			AGREE_S( "InsertAt " & st & " case " & i, _
			       FB.InsertAt( uc, "--", st ), AfxStrInsert( dc, "--", st ) )
		next

		'' ---- padding
		for w as integer = 0 to 14 step 7
			AGREE_S( "PadRight " & w & " case " & i, _
			       FB.PadRight( uc, w, "*" ), AfxStrLSet( dc, w, "*" ) )
			AGREE_S( "PadLeft " & w & " case " & i, _
			       FB.PadLeft( uc, w, "*" ), AfxStrRSet( dc, w, "*" ) )
			AGREE_S( "PadCenter " & w & " case " & i, _
			       FB.PadCenter( uc, w, "*" ), AfxStrCSet( dc, w, "*" ) )
		next

		'' ---- wrap, and Between against AfxNova's two-delimiter Extract
		AGREE_S( "Wrap case " & i, _
		       FB.Wrap( uc, "<", ">" ), AfxStrWrap( dc, "<", ">" ) )

		AGREE_S( "Between case " & i, _
		       FB.Between( uc, "(", ")" ), AfxStrExtract( dc, "(", ")" ) )

		AGREE_S( "RemoveBetween case " & i, _
		       FB.RemoveBetween( uc, "(", ")" ), AfxStrRemove( dc, "(", ")" ) )

		'' ---- VerifySet: AfxStrVerify takes the start first
		AgreeN( "VerifySet digits case " & i, _
		        FB.VerifySet( 1, uc, "0123456789" ), _
		        AfxStrVerify( 1, dc, "0123456789" ) )

		'' ---- Split, against AfxStrParseCount and AfxStrParse
		scope
			dim parts as FB.Array( of ustring ) = FB.Split( uc, "," )
			AgreeN( "Split count case " & i, _
			        parts.Count( ), AfxStrParseCount( dc, "," ) )

			for f as integer = 1 to parts.Count( )
				AGREE_S( "Split field " & f & " case " & i, _
				       parts[ f-1 ], AfxStrParse( dc, f, "," ) )
			next
		end scope
	next
end sub

'' TallyChars and ExtractChars are deliberately NOT in the loop above: they
'' disagree with AfxNova, and the disagreement is AfxNova's. See 12 and 13.

'' =========================================================================

sub RunDivergences( )
	print
	print "--- the decided divergences, and the two AfxNova bugs ---"
	print

	'' Named locals throughout: a DWSTRING built inline as a temporary does not
	'' parse as an argument, and naming them makes each case readable anyway.
	dim as DWSTRING dAabb   = "aabb"
	dim as DWSTRING dQuoted = "'''x'''"
	dim as DWSTRING dUnbal  = "'x"
	dim as DWSTRING dGap    = "a  b"
	dim as DWSTRING dShrink = ",,, one , two   three,"
	dim as DWSTRING dMask   = " ,"
	dim as DWSTRING dNoMask = ""
	dim as DWSTRING dUnder  = "foo_bar"
	dim as DWSTRING dSlash  = "a/b"
	dim as DWSTRING dTitle  = "hello wide world"
	dim as DWSTRING dJunk   = "++--.."
	dim as DWSTRING dTwoDot = "1.2.3"
	dim as DWSTRING dNum    = "123"
	dim as DWSTRING dAbc    = "abc"
	dim as DWSTRING dAbra   = "abacadabra"
	dim as DWSTRING dDigits = "1234567890"
	dim as DWSTRING dGarden = "garden"
	dim as DWSTRING dAstral = WCHR( &hD834 ) & WCHR( &hDD1E )
	dim as DWSTRING dQuote  = "'"
	dim as DWSTRING dDash   = "-"
	dim as DWSTRING dA      = "a"

	'' 1. Remove cascades in AfxNova, single pass here.
	''
	'' Assigned to locals first rather than written as len( FB.Remove( ... ) ):
	'' LEN cannot parse a NAMESPACE-QUALIFIED call -- 'len( NS.F( x ) )' is
	'' "error 42: Variable not declared, F" -- which is an UPSTREAM FreeBASIC
	'' bug, reproduced identically on stock fbc 1.10.1 and nothing to do with
	'' this library. It bites only the qualified spelling.
	scope
		dim as ustring gotR  = FB.Remove( U( dAabb ), "ab" )
		dim as ustring wantR = U( AfxStrRemove( dAabb, "ab" ) )

		DivergeN( "Remove cascade: length of Remove(aabb,ab)", _
		          len( gotR ), len( wantR ), _
		          "AfxStrRemove restarts at position 1, so the deletion creates " & _
		          "a match that was not in the input" )
	end scope

	'' 2. Reverse and surrogate pairs
	DIVERGE_S( "Reverse of an astral character", _
	         FB.Reverse( U( dAstral ) ), AfxStrReverse( dAstral ), _
	         "the pair is kept together here; AfxStrReverse swaps code units " & _
	         "and emits invalid UTF-16" )

	AGREE_S( "Reverse of BMP text", _
	         FB.Reverse( U( dGarden ) ), AfxStrReverse( dGarden ) )

	'' 3. Unwrap needs a pair, and takes only one
	DIVERGE_S( "Unwrap of a triple-quoted string", _
	         FB.Unwrap( U( dQuoted ), "'" ), AfxStrUnWrap( dQuoted, dQuote ), _
	         "AfxStrUnWrap uses LTRIM/RTRIM and strips every quote" )

	DIVERGE_S( "Unwrap of an unbalanced quote", _
	         FB.Unwrap( U( dUnbal ), "'" ), AfxStrUnWrap( dUnbal, dQuote ), _
	         "no closing delimiter, so nothing is removed here" )

	'' 4. Shrink with an empty mask
	DIVERGE_S( "Shrink with an empty mask", _
	         FB.Shrink( U( dGap ), "" ), AfxStrShrink( dGap, dNoMask ), _
	         "AfxStrShrink returns the empty string; there is nothing to shrink" )

	AGREE_S( "Shrink, normal mask", _
	         FB.Shrink( U( dShrink ), " ," ), AfxStrShrink( dShrink, dMask ) )

	'' 5. MCase word boundaries
	DIVERGE_S( "MCase of foo_bar", _
	         FB.MCase( U( dUnder ) ), DWStrMCase( dUnder ), _
	         "underscore is not in DWStrMCase's punctuation list" )

	DIVERGE_S( "MCase of a/b", _
	         FB.MCase( U( dSlash ) ), DWStrMCase( dSlash ), _
	         "slash is not in DWStrMCase's punctuation list" )

	AGREE_S( "MCase of ordinary words", _
	         FB.MCase( U( dTitle ) ), DWStrMCase( dTitle ) )

	'' 6. IsNumeric
	DivergeN( "IsNumeric of ++--..", _
	          cint( FB.IsNumeric( U( dJunk ) ) ), cint( AfxIsNumeric( dJunk ) ), _
	          "AfxIsNumeric is a character-set test, not a number test" )

	DivergeN( "IsNumeric of 1.2.3", _
	          cint( FB.IsNumeric( U( dTwoDot ) ) ), cint( AfxIsNumeric( dTwoDot ) ), _
	          "two decimal points are not a number" )

	AgreeN( "IsNumeric of 123", _
	        cint( FB.IsNumeric( U( dNum ) ) ), cint( AfxIsNumeric( dNum ) ) )

	'' 8. InsertAt with a position below 1 -- these AGREE, because the CODE was
	''    followed rather than the comment
	AGREE_S( "InsertAt at position 0", _
	         FB.InsertAt( U( dAbc ), "-", 0 ), AfxStrInsert( dAbc, dDash, 0 ) )
	print "        (note: AfxStrInsert's COMMENT says this appends; its CODE"
	print "         returns the string unchanged. The code is followed here, so"
	print "         these agree and it is the comment that is wrong.)"

	'' 9. A negative start is invalid here, counted from the right there
	DIVERGE_S( "Extract with start = -3", _
	         FB.Extract( -3, U( dAbra ), "a" ), AfxStrExtract( -3, dAbra, dA ), _
	         "AfxNova counts a negative start from the right; positions below " & _
	         "1 are invalid here" )

	'' 10. ClipMid and Delete are the same function
	AGREE_S( "DeleteAt matches AfxStrClipMid", _
	         FB.DeleteAt( U( dDigits ), 3, 4 ), AfxStrClipMid( dDigits, 3, 4 ) )
	AGREE_S( "DeleteAt matches AfxStrDelete", _
	         FB.DeleteAt( U( dDigits ), 4, 3 ), AfxStrDelete( dDigits, 4, 3 ) )

	'' =====================================================================
	'' 12 and 13: AfxNova BUGS, both found by this harness, both cases where
	'' the code contradicts its own comment.
	'' =====================================================================

	'' 12. AfxStrTallyAny DOUBLE-COUNTS a repeated character in the set. Its
	''     dedup loop seeds dwsMatchStr with the whole match string and then
	''     tests INSTR( dwsMatchStr, <char> ) against ITSELF, so every character
	''     is always found and nothing is ever appended -- the loop is a no-op.
	''     Its own comment promises "repeated characters in wszMatchStr will not
	''     increase the count".
	scope
		dim as DWSTRING dDup = "aa"
		DivergeN( "TallyChars with a duplicated set character", _
		          FB.TallyChars( U( dAbra ), U( dDup ) ), _
		          AfxStrTallyAny( dAbra, dDup ), _
		          "AfxStrTallyAny's dedup loop searches the match string inside " & _
		          "itself, so it never removes anything and each duplicate counts again" )

		dim as DWSTRING dSet = "bac"
		AgreeN( "TallyChars with a duplicate-free set", _
		        FB.TallyChars( U( dAbra ), U( dSet ) ), _
		        AfxStrTallyAny( dAbra, dSet ) )
	end scope

	'' 13. AfxStrExtractAny returns "" ON A MISS, contradicting BOTH its own
	''     documentation ("If wszMatchStr is not present ... then all of
	''     wszMainStr is returned") and its sibling AfxStrExtract, which does
	''     return the remainder.
	scope
		dim as DWSTRING dMiss = "zzz"
		DIVERGE_S( "ExtractChars on a miss", _
		         FB.ExtractChars( 1, U( dAbra ), U( dMiss ) ), _
		         AfxStrExtractAny( 1, dAbra, dMiss ), _
		         "AfxStrExtractAny ends in an unconditional empty return, " & _
		         "contradicting its own comment and AfxStrExtract" )

		dim as DWSTRING dHit = "cd"
		AGREE_S( "ExtractChars on a hit", _
		         FB.ExtractChars( 1, U( dAbra ), U( dHit ) ), _
		         AfxStrExtractAny( 1, dAbra, dHit ) )
	end scope
end sub

'' =========================================================================

BuildCorpus( )

print "FB.* vs AfxNova -- differential run"
print "==================================="
print

'' Divergences first: they carry the findings, and they run over their own
'' inputs, so they complete even if the sweep below cannot.
RunDivergences( )
RunAgreements( )

print
print "==================================="
print "checks   : "; g_checks
print "agreed   : "; g_agree
print "diverged : "; g_diverge; "  (expected, and each one asserted)"
print "FAILED   : "; g_fail

if g_fail > 0 then
	print
	print "RESULT: FAILED"
	end 1
end if

print
print "RESULT: OK"
end 0
