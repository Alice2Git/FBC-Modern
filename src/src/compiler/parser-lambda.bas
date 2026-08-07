'' Lambda expressions -- non-capturing
''
'' Sketch S.3.  'function( byval x as long ) as long ... end function' in
'' EXPRESSION position, producing an ordinary procedure pointer:
''
''     dim double_ as function( byval x as long ) as long = _
''         function( byval x as long ) as long : return x * 2 : end function
''
'' No compatibility risk: 'function' and 'sub' in expression position are a
'' syntax error today -- verified against this compiler, not assumed:
''
''     error 9: Expected expression, found 'function'
''
'' A non-capturing lambda lowers to a plain module-level procedure plus its
'' address, so the result is type-identical to '@myproc' and passes to any
'' matching procptr parameter -- every Win32-style callback keeps working.
''
'' THE SHAPE OF THE PROBLEM.  A procedure body cannot be parsed where the
'' expression sits: astProcBegin/astProcEnd are not a stack, so a body cannot be
'' opened while another is open.  The generics work already solved this for
'' member bodies, and this file reuses that solution wholesale -- capture the
'' tokens, replay the HEADER immediately at module level so the call site has a
'' real symbol to point at, and queue the BODY until the parser next reaches a
'' module-level statement boundary.

#include once "fb.bi"
#include once "fbint.bi"
#include once "parser.bi"
#include once "ast.bi"

'' One lambda owing a body replay.
type FB_LAMBDA
	sym             as FBSYMBOL ptr             '' the synthesised procedure
	kindtk          as integer                  '' FB_TK_SUB or FB_TK_FUNCTION
	hdrhead         as FB_GENTOK ptr            '' '( params )' + optional 'as <type>'
	hdrtail         as FB_GENTOK ptr
	tokhead         as FB_GENTOK ptr            '' the body, terminator NOT included
	toktail         as FB_GENTOK ptr
	srcline         as integer
	srcfile         as zstring ptr
	done            as integer
end type

type FB_LAMBDACTX
	inited          as integer
	list            as TLIST
	pending         as integer
	draining        as integer

	'' Non-zero while a lambda replay is running.
	''
	'' cProgram( ) calls lambdaDrainBodies( ) at its own statement boundaries,
	'' and a HEADER replay runs cProgram( ) -- so a second lambda's header
	'' replay would drain the FIRST lambda's body from inside it, opening a
	'' procedure body while one was already open. That is exactly the
	'' astProcBegin/astProcEnd-is-not-a-stack limit this whole design exists to
	'' avoid, reached through a back door. Symptom: any two lambdas in one
	'' procedure, and the enclosing 'end sub' was reported as
	'' 'error 126: Expected END FUNCTION'.
	inreplay        as integer
end type

dim shared as FB_LAMBDACTX lambdactx

'' The same flags the generic capture uses, and for the same reason: the body is
'' re-parsed as source, not expanded as a macro.
#define LAMTOK_FLAGS (LEXCHECK_NOSUFFIX or LEXCHECK_NOQUOTES)

'' A local copy of the generic capture's token appender: that one is private to
'' parser-generic-capture.bas, and widening its visibility for fifteen lines
'' would couple two features that only happen to share a data structure.
private function hAddTok _
	( _
		byref head as FB_GENTOK ptr, _
		byref tail as FB_GENTOK ptr, _
		byval text as const zstring ptr, _
		byval linenum as integer _
	) as FB_GENTOK ptr

	dim as FB_GENTOK ptr n = callocate( len( FB_GENTOK ) )

	n->type = FB_DEFTOK_TYPE_TEX
	n->text = ZstrAllocate( len( *text ) )
	*n->text = *text
	n->linenum = linenum
	n->prev = tail
	n->next = NULL

	if( tail ) then
		tail->next = n
	else
		head = n
	end if
	tail = n

	function = n
end function

'' Capture '( params )' and then the optional result type.
''
'' hCaptureProcHeader( ) next door is LINE-terminated, which is right for a
'' generic procedure -- its header is the whole line -- and wrong here: a lambda
'' sits mid-expression and its body can begin on the same line.
''
'' So the parameter list is taken by PAREN BALANCE, and whatever follows it is
'' taken up to the first ':' or end of line at paren depth zero. Depth zero is
'' what makes a procptr result type work, since that type has parentheses of its
'' own:
''
''     function( ) as function( byval x as long ) as long : ... : end function
''             ^^^ params      ^^^^^^^^^^^^^^^^^^^^^^^^^^ result type
private function hCaptureLambdaHeader( byval lam as FB_LAMBDA ptr ) as integer
	dim as integer depth = any

	'' An optional calling convention comes between the keyword and the '('.
	'' Not optional in practice: qsort's comparator is CDECL and most Win32
	'' callbacks are STDCALL, so without this the lambda cannot be used for the
	'' very APIs that motivate the feature.
	select case lexGetToken( LAMTOK_FLAGS )
	case FB_TK_CDECL, FB_TK_STDCALL, FB_TK_PASCAL, FB_TK_THISCALL
		hAddTok( lam->hdrhead, lam->hdrtail, lexGetText( ), lexLineNum( ) )
		lexSkipToken( LAMTOK_FLAGS )
	end select

	if( lexGetToken( LAMTOK_FLAGS ) <> CHAR_LPRNT ) then
		errReport( FB_ERRMSG_EXPECTEDLPRNT )
		return FALSE
	end if

	depth = 0
	do
		select case lexGetToken( LAMTOK_FLAGS )
		case FB_TK_EOF, FB_TK_EOL
			errReport( FB_ERRMSG_UNBALANCEDLAMBDAHEADER )
			return FALSE

		case CHAR_LPRNT
			depth += 1

		case CHAR_RPRNT
			depth -= 1
		end select

		hAddTok( lam->hdrhead, lam->hdrtail, lexGetText( ), lexLineNum( ) )
		lexSkipToken( LAMTOK_FLAGS )
	loop while( depth > 0 )

	'' the result type, if any -- to ':' or end of line, at depth zero
	depth = 0
	do
		select case lexGetToken( LAMTOK_FLAGS )
		case FB_TK_EOF
			errReport( FB_ERRMSG_UNBALANCEDLAMBDAHEADER )
			return FALSE

		case FB_TK_EOL, FB_TK_COMMENT, FB_TK_REM
			exit do

		case FB_TK_STMTSEP
			if( depth = 0 ) then
				exit do
			end if

		case CHAR_LPRNT
			depth += 1

		case CHAR_RPRNT
			depth -= 1
		end select

		hAddTok( lam->hdrhead, lam->hdrtail, lexGetText( ), lexLineNum( ) )
		lexSkipToken( LAMTOK_FLAGS )
	loop

	'' drop the ':' or EOL that ended the header
	select case lexGetToken( LAMTOK_FLAGS )
	case FB_TK_EOL, FB_TK_STMTSEP
		lexSkipToken( LAMTOK_FLAGS )
	end select

	function = TRUE
end function

'' Capture the body up to its matching END SUB|FUNCTION, which is consumed but
'' not recorded.
''
'' DEPTH-COUNTED, not "stop at the first END" the way hCaptureProcBody( ) does.
'' That one is allowed its shortcut because procedures cannot nest in FreeBASIC;
'' lambdas can, and a lambda inside a lambda would truncate the outer capture at
'' the inner one's terminator.
private function hCaptureLambdaBody( byval lam as FB_LAMBDA ptr ) as integer
	dim as integer depth = 1, tk = any

	do
		tk = lexGetToken( LAMTOK_FLAGS )

		select case as const tk
		case FB_TK_EOF
			errReport( FB_ERRMSG_UNBALANCEDLAMBDABODY )
			return FALSE

		'' 'exit sub' / 'exit function' name the kind without opening one, so
		'' both tokens are recorded together and the second is never examined
		case FB_TK_EXIT
			hAddTok( lam->tokhead, lam->toktail, lexGetText( ), lexLineNum( ) )
			lexSkipToken( LAMTOK_FLAGS )
			hAddTok( lam->tokhead, lam->toktail, lexGetText( ), lexLineNum( ) )
			lexSkipToken( LAMTOK_FLAGS )
			continue do

		case FB_TK_END
			select case lexGetLookAhead( 1, LAMTOK_FLAGS )
			case FB_TK_SUB, FB_TK_FUNCTION
				depth -= 1
				if( depth = 0 ) then
					'' our own terminator: consume both without recording
					lexSkipToken( LAMTOK_FLAGS )
					lexSkipToken( LAMTOK_FLAGS )
					exit do
				end if

				'' a nested lambda closing -- record both together, or the
				'' SUB|FUNCTION would be re-examined and counted as opening one
				hAddTok( lam->tokhead, lam->toktail, lexGetText( ), lexLineNum( ) )
				lexSkipToken( LAMTOK_FLAGS )
				hAddTok( lam->tokhead, lam->toktail, lexGetText( ), lexLineNum( ) )
				lexSkipToken( LAMTOK_FLAGS )
				continue do
			end select

		case FB_TK_SUB, FB_TK_FUNCTION
			'' a nested lambda opening
			depth += 1
		end select

		hAddTok( lam->tokhead, lam->toktail, lexGetText( ), lexLineNum( ) )
		lexSkipToken( LAMTOK_FLAGS )
	loop

	function = TRUE
end function

private function hKeyword( byval kindtk as integer ) as string
	if( kindtk = FB_TK_SUB ) then
		return "sub"
	end if
	function = "function"
end function

'' Replay one lambda's body at module level. Called at a statement boundary,
'' where a procedure could legitimately have been written by hand.
private sub hReplayLambdaBody( byval lam as FB_LAMBDA ptr )
	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as string text
	dim as integer firstline = any
	dim as string kw = hKeyword( lam->kindtk )

	'' NOTE the space before the header. genFlattenTokens( ) separates tokens
	'' but does not lead with one, so without it a calling convention would be
	'' pasted onto the name -- 'Lt_0003cdecl( ... )'. Harmless when the header
	'' starts with '(', which is why it went unnoticed until a cdecl lambda.
	text = kw + " " + *symbGetName( lam->sym ) + " " + _
	       genFlattenTokens( lam->hdrhead, firstline ) + LFCHAR + _
	       genFlattenTokens( lam->tokhead, firstline ) + LFCHAR + _
	       "end " + kw

	'' hidelocals = FALSE: this replay parses a BODY, and its own locals and
	'' parameters must shadow normally. See genEnterGlobalScope( ).
	genEnterGlobalScope( gs, NULL, FALSE )

	lambdactx.inreplay += 1
	if( genReplayBegin( st, text, lam->srcline, lam->srcfile ) ) then
		cProgram( )
		genReplayEnd( st )
	end if
	lambdactx.inreplay -= 1

	genLeaveGlobalScope( gs )
end sub

'' Replay every lambda body owed. Safe at any module-level statement boundary,
'' and cheap when there is nothing to do, which is the common case.
sub lambdaDrainBodies( )
	if( lambdactx.pending = 0 ) then
		exit sub
	end if

	'' never from inside a replay -- see FB_LAMBDACTX.inreplay
	if( lambdactx.inreplay > 0 ) then
		exit sub
	end if

	'' a replayed body may itself contain lambdas, which queue more work; the
	'' loop below handles that rather than re-entering here
	if( lambdactx.draining ) then
		exit sub
	end if

	lambdactx.draining = TRUE

	do
		dim as FB_LAMBDA ptr p = listGetHead( @lambdactx.list )
		dim as integer didwork = FALSE

		while( p )
			if( p->done = FALSE ) then
				p->done = TRUE
				lambdactx.pending -= 1
				didwork = TRUE

				hReplayLambdaBody( p )

				'' the replay may have appended entries, so restart the walk
				'' rather than trusting the node we are standing on
				exit while
			end if
			p = listGetNext( p )
		wend

		if( didwork = FALSE ) then
			exit do
		end if
	loop

	lambdactx.draining = FALSE
end sub

'' LambdaExpr  =  SUB|FUNCTION '(' ParamList? ')' (AS SymbolType)? Body
''                END SUB|FUNCTION .
''
'' On entry the current token is SUB or FUNCTION.
function cLambdaExpr( ) as ASTNODE ptr
	dim as FB_LAMBDA ptr lam = any
	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as integer firstline = any, kindtk = any, startline = any
	dim as string text, kw
	dim as zstring * FB_MAXNAMELEN+1 id
	dim as FBSYMBOL ptr sym = any

	function = NULL

	kindtk = lexGetToken( )
	startline = lexLineNum( )

	if( lambdactx.inited = FALSE ) then
		listInit( @lambdactx.list, 16, len( FB_LAMBDA ), LIST_FLAGS_NOCLEAR )
		lambdactx.inited = TRUE
	end if

	lam = listNewNode( @lambdactx.list )
	lam->sym     = NULL
	lam->kindtk  = kindtk
	lam->hdrhead = NULL
	lam->hdrtail = NULL
	lam->tokhead = NULL
	lam->toktail = NULL
	lam->srcline = startline
	lam->done    = TRUE
	lam->srcfile = ZstrAllocate( len( env.inf.name ) )
	*lam->srcfile = env.inf.name

	'' SUB|FUNCTION
	lexSkipToken( LAMTOK_FLAGS )

	if( hCaptureLambdaHeader( lam ) = FALSE ) then
		return NULL
	end if
	if( hCaptureLambdaBody( lam ) = FALSE ) then
		return NULL
	end if

	'' A deterministic, unique name. symbUniqueId( TRUE ) -- the argument asks
	'' for a name that is legal FreeBASIC, which matters because this one is
	'' pasted into source text and re-parsed rather than only ever being a
	'' symbol.
	id = *symbUniqueId( TRUE )
	kw = hKeyword( kindtk )

	'' Replay the HEADER now, as a declaration, so this expression has a real
	'' FBSYMBOL to take the address of. The body cannot be parsed here -- there
	'' is already a procedure open -- so only the prototype is created.
	text = "declare " + kw + " " + id + " " + genFlattenTokens( lam->hdrhead, firstline )

	'' hidelocals = TRUE: a DECLARATION replay creates no locals of its own, and
	'' the call site's locals must not be visible to it.
	genEnterGlobalScope( gs, NULL, TRUE )

	'' genEnterGlobalScope( ) moves the PARSE to module level, but the
	'' compound-statement stack still holds whatever is open at the call site --
	'' the enclosing SUB, an IF, a FOR. cProcDecl( ) gates on that stack through
	'' cCompStmtIsAllowed( ), so the replayed 'declare' was refused with
	'' 'error 96: Illegal inside a compound statement or scoped block'.
	''
	'' The stack is emptied for the duration. Done BEFORE genReplayBegin( ), so
	'' the balance assert in genRestoreState( ) compares NULL against the NULL it
	'' saved, and restored after genReplayEnd( ) so the caller's own nesting is
	'' untouched.
	dim as any ptr savedtos = parser.stmt.stk.tos
	parser.stmt.stk.tos = NULL

	lambdactx.inreplay += 1
	if( genReplayBegin( st, text, startline, lam->srcfile ) ) then
		cProgram( )
		genReplayEnd( st )
	end if
	lambdactx.inreplay -= 1

	parser.stmt.stk.tos = savedtos

	genLeaveGlobalScope( gs )

	'' preservecase = FALSE: symbols are stored up-cased unless explicitly asked
	'' otherwise, and the replayed 'declare' did not ask. Looking the name back
	'' up case-sensitively finds nothing -- measured, not assumed.
	sym = symbLookupByNameAndClass( @symbGetGlobalNamespc( ), id, _
	                                FB_SYMBCLASS_PROC, FALSE )
	if( sym = NULL ) then
		'' the header did not parse; it has already been diagnosed
		return NULL
	end if

	lam->sym = sym
	lam->done = FALSE
	lambdactx.pending += 1

	'' '@proc' -- astNewVAR( ) manufactures the procptr subtype through
	'' symbAddProcPtrFromFunction( ), so the result is type-identical to what
	'' '@myproc' produces and matches any procptr with the same signature.
	function = astBuildProcAddrof( sym )
end function
