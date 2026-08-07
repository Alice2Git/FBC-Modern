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

const LAMBDA_MAXCAPTURES = 32

'' One entry of a capture list.
type FB_LAMBDACAP
	id              as zstring * FB_MAXNAMELEN+1   '' the name as written
	sym             as FBSYMBOL ptr                '' the captured local
	isref           as integer                     '' BYREF, rather than BYVAL
	fld             as zstring * FB_MAXNAMELEN+1   '' the closure field's name
end type

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

	'' capturing lambdas only
	clo             as FBSYMBOL ptr             '' the synthesised closure struct
	capcount        as integer
	caps( 0 to LAMBDA_MAXCAPTURES-1 ) as FB_LAMBDACAP
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

'' A per-MODULE component for synthesised names.
''
'' symbUniqueId( ) is unique within one module only, so two modules that each
'' contain a lambda both produced 'LT_0003' and the link failed:
''
''     multiple definition of `LT_0003'
''     multiple definition of `LT_0004::__FBINVOKE(int)'
''
'' 'private' would fix the plain procedure but not the closure, whose
'' __FBINVOKE is a member of a module-level struct and cannot be given internal
'' linkage. So the NAME carries the module instead, and both kinds are fixed by
'' the same rule.
''
'' Derived from the source file name, which is stable for a given file and
'' therefore keeps the name deterministic -- separate compilation requires that
'' the same source produce the same symbol every time.
private function hModuleTag( ) as string
	'' Recomputed per call, NOT cached in a static: fbc compiles every module
	'' of a multi-module build in ONE process, so a process-lifetime cache
	'' handed the second module the first module's tag and the link failed
	'' exactly as before.
	dim as ulongint h = 1469598103934665603ull      '' FNV-1a
	dim as string nm = env.inf.name

	for i as integer = 0 to len( nm )-1
		h xor= nm[i]
		h *= 1099511628211ull
	next

	function = hex( culngint( h ) )
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
	if( lam->clo ) then
		'' capturing: a MEMBER of the closure struct, opened with one BYREF
		'' alias per capture so the captured names resolve inside the body with
		'' no rewriting of the body itself.
		''
		'' The aliases are what make this safe. The alternative -- substituting
		'' '*this.__cap_x' for every 'x' in the captured tokens -- would also
		'' rewrite a LOCAL named x declared inside the lambda, silently
		'' redirecting it to the capture. With a real declaration, FreeBASIC's
		'' own scoping decides, and a colliding local is a duplicate-definition
		'' error the author can see.
		''
		'' typeof( ) avoids needing the captured type as text a second time, and
		'' works for UDTs, strings and containers alike -- measured.
		text = kw + " " + *symbGetName( lam->clo ) + "." + FB_INVOKE_NAME + " " + _
		       genFlattenTokens( lam->hdrhead, firstline ) + LFCHAR

		for i as integer = 0 to lam->capcount-1
			with lam->caps( i )
				if( .isref ) then
					text += "dim byref as typeof( *this." + .fld + " ) " + _
					        .id + " = *this." + .fld + LFCHAR
				else
					text += "dim byref as typeof( this." + .fld + " ) " + _
					        .id + " = this." + .fld + LFCHAR
				end if
			end with
		next

		text += genFlattenTokens( lam->tokhead, firstline ) + LFCHAR + "end " + kw
	else
		text = kw + " " + *symbGetName( lam->sym ) + " " + _
		       genFlattenTokens( lam->hdrhead, firstline ) + LFCHAR + _
		       genFlattenTokens( lam->tokhead, firstline ) + LFCHAR + _
		       "end " + kw
	end if


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

'' CaptureList  =  '[' ( (BYVAL|BYREF) Identifier (',' ...)* )? ']' .
''
'' Sits between the keyword and the parameter list, where nothing may legally
'' appear today, so there is no ambiguity with array indexing.
''
'' EVERY CAPTURE CARRIES AN EXPLICIT MODE. No default, no bare '[ total ]', no
'' C++-style '[&]' / '[=]' wildcards. In a language with manual lifetimes the
'' mode is the lifetime question, and inferring it is how a closure ends up
'' holding a reference to a destroyed frame. An EMPTY list is allowed and means
'' the same as no list, so a capture can be deleted without re-punctuating.
private function hCaptureList( byval lam as FB_LAMBDA ptr ) as integer
	dim as FB_TOKEN tk = any
	dim as FB_TKCLASS tc = any
	dim as FBSYMCHAIN ptr chain_ = any

	'' '['
	lexSkipToken( LAMTOK_FLAGS )

	if( lexGetToken( LAMTOK_FLAGS ) = CHAR_RBRACKET ) then
		lexSkipToken( LAMTOK_FLAGS )
		return TRUE
	end if

	do
		if( lam->capcount >= LAMBDA_MAXCAPTURES ) then
			errReport( FB_ERRMSG_TOOMANYCAPTURES )
			return FALSE
		end if

		dim as integer isref = any

		select case lexGetToken( LAMTOK_FLAGS )
		case FB_TK_BYVAL
			isref = FALSE
		case FB_TK_BYREF
			isref = TRUE
		case else
			errReport( FB_ERRMSG_CAPTURENEEDSMODE )
			return FALSE
		end select
		lexSkipToken( LAMTOK_FLAGS )

		if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
			errReport( FB_ERRMSG_EXPECTEDIDENTIFIER )
			return FALSE
		end if

		with lam->caps( lam->capcount )
			.id = *lexGetText( )
			.isref = isref

			'' Resolved HERE, at the expression, which is the only place the
			'' captured variable is in scope: the closure struct and its
			'' __FBINVOKE are built at module level, where it is not.
			chain_ = symbLookup( lexGetText( ), tk, tc )
			if( chain_ = NULL ) then
				errReportEx( FB_ERRMSG_CAPTUREUNDECLARED, .id )
				return FALSE
			end if
			.sym = chain_->sym
			if( .sym = NULL ) then
				errReportEx( FB_ERRMSG_CAPTUREUNDECLARED, .id )
				return FALSE
			end if
			if( symbIsVar( .sym ) = FALSE ) then
				errReportEx( FB_ERRMSG_CAPTUREUNDECLARED, .id )
				return FALSE
			end if

			.fld = "__cap_" & .id
		end with

		lam->capcount += 1
		lexSkipToken( LAMTOK_FLAGS )

		if( lexGetToken( LAMTOK_FLAGS ) <> CHAR_COMMA ) then
			exit do
		end if
		lexSkipToken( LAMTOK_FLAGS )
	loop

	if( lexGetToken( LAMTOK_FLAGS ) <> CHAR_RBRACKET ) then
		errReport( FB_ERRMSG_EXPECTEDRBRACKET )
		return FALSE
	end if
	lexSkipToken( LAMTOK_FLAGS )

	function = TRUE
end function

'' Build the closure struct, at module level, as replayed source.
''
''     type <Clo>
''         as <T> ptr __cap_total      '' BYREF -- a pointer to the caller's local
''         as <T>     __cap_base       '' BYVAL -- a copy taken at evaluation
''         declare <kind> __FBINVOKE <header>
''     end type
''
'' Hoisted to module level because a UDT declared inside a scope may not have
'' member procedures (hDisallowNestedClasses), and __FBINVOKE is one. That is
'' deviation D1, already carried by the generics work: the closure TYPE outlives
'' the scope that named it.
''
'' The field types come from symbTypeToStr( ) on the captured symbol, because the
'' hoisted declaration cannot name the types of locals that are not in scope
'' there -- 'typeof( total )' would not resolve at module level.
private function hBuildClosure _
	( _
		byval lam as FB_LAMBDA ptr, _
		byref cloid as zstring, _
		byref hdr as string _
	) as integer

	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as string text
	dim as string kw = hKeyword( lam->kindtk )

	text = "type " + cloid + LFCHAR

	for i as integer = 0 to lam->capcount-1
		with lam->caps( i )
			dim as string ty = symbTypeToStr( symbGetFullType( .sym ), symbGetSubtype( .sym ) )
			if( .isref ) then
				text += "as " + ty + " ptr " + .fld + LFCHAR
			else
				text += "as " + ty + " " + .fld + LFCHAR
			end if
		end with
	next

	text += "declare " + kw + " " + FB_INVOKE_NAME + " " + hdr + LFCHAR
	text += "end type"

	genEnterGlobalScope( gs, NULL, TRUE )

	'' see the note in cLambdaExpr: widen the top entry, never empty the stack
	dim as FB_CMPSTMTSTK ptr stk = stackGetTOS( @parser.stmt.stk )
	dim as integer savedmask = 0
	if( stk ) then
		savedmask = stk->allowmask
		stk->allowmask = -1
	end if

	'' env.includerec is bumped for the duration too. cProgram( ) ends with
	''     if( env.includerec = 0 ) then cCompStmtCheck( )
	'' and at the replay text's EOF that check sees the CALL SITE's still-open
	'' SUB and reports 'error 125: Expected END SUB'. A replay is not the end of
	'' the module, so it must not run the end-of-module check.
	''
	'' This is what emptying stk.tos used to hide, before that was replaced --
	'' one hack was covering for the other.
	env.includerec += 1
	lambdactx.inreplay += 1
	if( genReplayBegin( st, text, lam->srcline, lam->srcfile ) ) then
		cProgram( )
		genReplayEnd( st )
	end if
	lambdactx.inreplay -= 1
	env.includerec -= 1

	if( stk ) then
		stk->allowmask = savedmask
	end if
	genLeaveGlobalScope( gs )

	lam->clo = symbLookupByNameAndClass( @symbGetGlobalNamespc( ), cloid, _
	                                     FB_SYMBCLASS_STRUCT, FALSE )
	if( lam->clo = NULL ) then
		return FALSE
	end if

	lam->clo->attrib or= FB_SYMBATTRIB_CLOSURE
	function = TRUE
end function

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
	lam->clo     = NULL
	lam->capcount = 0
	lam->srcfile = ZstrAllocate( len( env.inf.name ) )
	*lam->srcfile = env.inf.name

	'' SUB|FUNCTION
	lexSkipToken( LAMTOK_FLAGS )

	'' CaptureList?
	dim as integer iscapturing = FALSE
	if( lexGetToken( LAMTOK_FLAGS ) = CHAR_LBRACKET ) then
		if( hCaptureList( lam ) = FALSE ) then
			return NULL
		end if

		'' An EMPTY list is the non-capturing form, not a closure with no
		'' captures: a closure struct with no fields is refused outright by
		'' FreeBASIC ('error 256: An ENUM, TYPE or UNION cannot be empty'), and
		'' 'sub[ ]( ... )' should mean exactly what 'sub( ... )' means anyway.
		iscapturing = (lam->capcount > 0)
	end if

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
	id = "L" + hModuleTag( ) + "_" + *symbUniqueId( TRUE )
	kw = hKeyword( kindtk )

	'' ------------------------------------------------------------ capturing
	if( iscapturing ) then
		'' A closure has state and a procedure pointer has nowhere to put it, so
		'' the conversion does not exist. Reported HERE, against the expected
		'' type, because the fallback is 'error 24: Invalid data types', which is
		'' true but never mentions the capture that caused it.
		''
		'' parser.ctx_dtype is the target's type during an initializer or an
		'' assignment, which is where this is written in practice:
		''     dim f as Fn = function[ byval bias ]( ... )
		if( typeGetDtAndPtrOnly( parser.ctx_dtype ) = typeAddrOf( FB_DATATYPE_FUNCTION ) ) then
			errReport( FB_ERRMSG_CLOSURETOPROCPTR )
		end if

		dim as string hdr = genFlattenTokens( lam->hdrhead, firstline )

		if( hBuildClosure( lam, id, hdr ) = FALSE ) then
			return NULL
		end if

		lam->done = FALSE
		lambdactx.pending += 1

		'' The value of the expression is a closure OBJECT living in the
		'' enclosing scope -- no allocation, destroyed with the frame.
		''
		'' symbAddImplicitVar, not a temp: a temp dies at the end of the
		'' statement, and 'var f = sub[ ... ]' has to outlive that.
		dim as FBSYMBOL ptr tmp = symbAddImplicitVar( FB_DATATYPE_STRUCT, lam->clo, 0 )
		if( tmp = NULL ) then
			return NULL
		end if

		'' The symbol alone is not enough. Under the C backend a local is
		'' emitted from its DECL node, so without this the generated C used the
		'' temp without declaring it:
		''     error: 'TMP$3$1' undeclared (first use in this function)
		astAdd( astNewDECL( tmp, TRUE ) )

		'' Fill the captures. These are emitted BEFORE the statement being
		'' parsed, which is where they belong: a BYVAL capture is a snapshot
		'' taken when the lambda expression is evaluated.
		for i as integer = 0 to lam->capcount-1
			with lam->caps( i )
				dim as FBSYMBOL ptr fld = symbLookupByNameAndClass( lam->clo, _
				                          .fld, FB_SYMBCLASS_FIELD, FALSE )
				if( fld = NULL ) then
					return NULL
				end if

				dim as ASTNODE ptr dst = astBuildVarField( tmp, fld )
				dim as ASTNODE ptr src = any
				if( .isref ) then
					src = astNewADDROF( astNewVAR( .sym ) )
				else
					src = astNewVAR( .sym )
				end if

				astAdd( astNewASSIGN( dst, src ) )
			end with
		next

		return astNewVAR( tmp )
	end if

	'' -------------------------------------------------------- non-capturing

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
	'' cCompStmtIsAllowed( ), so a replayed declaration is refused with
	'' 'error 96: Illegal inside a compound statement or scoped block'.
	''
	'' Widening the TOP entry's allowmask, NOT setting stk.tos to NULL.
	'' cCompStmtIsAllowed( ) only ever inspects the top, so this is enough -- and
	'' emptying the stack is actively wrong: with tos = NULL the next push reuses
	'' the first node and OVERWRITES the enclosing SUB's entry. A bare 'declare'
	'' pushes nothing so it never showed, but the closure replay's
	'' 'type ... end type' does, and every statement after the lambda then failed
	'' with 'error 61: Illegal inside functions'.
	dim as FB_CMPSTMTSTK ptr stk = stackGetTOS( @parser.stmt.stk )
	dim as integer savedmask = 0
	if( stk ) then
		savedmask = stk->allowmask
		stk->allowmask = -1
	end if

	env.includerec += 1
	lambdactx.inreplay += 1
	if( genReplayBegin( st, text, startline, lam->srcfile ) ) then
		cProgram( )
		genReplayEnd( st )
	end if
	lambdactx.inreplay -= 1
	env.includerec -= 1

	if( stk ) then
		stk->allowmask = savedmask
	end if

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
