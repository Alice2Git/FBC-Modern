'' Generic body replay.
''
'' The capture half lives in parser-generic-capture.bas.  This is the other
'' half: it pushes a lexer context, feeds a captured body back through the
'' lexer, and re-runs the ordinary declaration parser over it.
''
'' Re-entering the parser mid-parse is the risky part.  fbIncludeFile() already
'' does lexPushCtx + lexInit + cProgram(), so the pattern is proven -- but it is
'' only ever triggered at a statement boundary, and it saves nothing except
'' env.inf, because '#include' is defined as "as if the text were here" and
'' state leaking outward is the point.  A generic replay is the opposite: it
'' happens in the middle of someone else's declaration, and must leave every
'' scrap of parser state exactly as it found it.
''
'' cTypeDecl() already does a hand-rolled version of this around hTypeAdd(),
'' with the comment "we have to store some contextual information, while
'' there's no proper scope stack".  It saves five fields.  This is the proper
'' one.
''
'' chng: aug/2026 written

#include once "fb.bi"
#include once "fbint.bi"
#include once "parser.bi"
#include once "ast.bi"
#include once "lex.bi"

'' Everything a replay must not disturb.
''
'' The compound-statement STACK is deliberately not copied: it has its own
'' push/pop discipline (cCompStmtPush/Pop), which already restores
'' parser.stmt.id and the .for/.do/.while/.select/.proc/.with shortcuts on the
'' way out.  Instead we assert that the replay left the stack at the depth it
'' found it -- an unbalanced replay would otherwise skew the caller and fail far
'' away from the cause.
''
'' parser.stmt.cnt is a different thing despite living next door: a running
'' count of statement separators, not a depth.  It IS copied, because replaying
'' a procedure body runs cProgram(), which bumps it once per line.
'' FB_PARSERSTATE and FB_GENSCOPE moved to parser.bi -- parser-lambda.bas
'' reuses this same replay/scope machinery.

sub genSaveState( byref st as FB_PARSERSTATE )
	st.options      = parser.options
	st.prntcnt      = parser.prntcnt
	st.nsprefix     = parser.nsprefix
	st.mangling     = parser.mangling
	st.stage        = parser.stage
	st.scope        = parser.scope
	st.currproc     = parser.currproc
	st.currblock    = parser.currblock
	st.ctx_dtype    = parser.ctx_dtype
	st.ctxsym       = parser.ctxsym
	st.have_eq      = parser.have_eq_outside_parens
	st.stmtcnt      = parser.stmt.cnt
	st.stmttos      = parser.stmt.stk.tos
	st.procheaderid = parser.procheaderid

	st.astproc      = ast.proc.curr
	st.astblock     = ast.currblock
	st.doemit       = ast.doemit
	st.typeinicount = ast.typeinicount

	st.inf          = env.inf

	st.laststmt     = errGetLastStmt( )
end sub

sub genRestoreState( byref st as FB_PARSERSTATE )
	parser.options      = st.options
	parser.prntcnt      = st.prntcnt
	parser.nsprefix     = st.nsprefix
	parser.mangling     = st.mangling
	parser.stage        = st.stage
	parser.scope        = st.scope
	parser.currproc     = st.currproc
	parser.currblock    = st.currblock
	parser.ctx_dtype    = st.ctx_dtype
	parser.ctxsym       = st.ctxsym
	parser.have_eq_outside_parens = st.have_eq
	parser.stmt.cnt     = st.stmtcnt
	parser.procheaderid = st.procheaderid

	ast.proc.curr   = st.astproc
	ast.currblock   = st.astblock
	ast.doemit      = st.doemit
	ast.typeinicount = st.typeinicount

	env.inf         = st.inf

	errSetLastStmt( st.laststmt )

	'' A replay that opened a compound statement and never closed it would
	'' leave the caller's stack skewed, and the failure would surface far away
	'' from the cause.  The stack nodes are pooled, so the same depth always
	'' means the same top-of-stack pointer.
	assert( parser.stmt.stk.tos = st.stmttos )
end sub

'' An instantiation is built as if at module level, whatever the parser was in
'' the middle of when it was asked for.
''
'' This is not cosmetic.  A UDT declared below module level may not have member
'' procedures -- hDisallowNestedClasses rejects them, because FreeBASIC has no
'' nested procedures and their bodies could never be implemented.  A member body
'' that instantiates another generic is parsed inside a procedure, so without
'' this every generic with methods is rejected the moment one is used from
'' inside another's body.
''
'' The synthetic namespace has to land under the GLOBAL namespace as well, not
'' under whatever namespace the request came from.  Instantiating Inner( of T )
'' from inside Outer( of T )'s member body otherwise buries Inner's namespace
'' inside Outer's, and replaying Inner's own member bodies then crashes the
'' compiler.  It is wrong on its own terms too: a type is its arguments, not its
'' use site, so Box( of long ) has to be one type however it was reached.
''
'' Done by moving the current symbol/hash table directly rather than with
'' symbNestBegin().  symbNestBegin() on a namespace already in scope -- and the
'' global one always is -- adds its hash table to the nested-hash list a second
'' time, and that list is threaded through the hash table itself, so the
'' duplicate points at itself and every later lookup spins forever.
''
'' This settles deviation D1 the other way from the shipped precedent for array
'' descriptor types (symbLookupInternallyMangledSubtype goes local when inside a
'' scope).  The cost is that a type argument naming a procedure-local UDT now
'' outlives that UDT's scope -- the hazard the FBARRAY comment in symb-var.bas
'' warns about.  The trade is deliberate: descriptor types have no methods, so
'' the local branch costs them nothing, while for generics it costs everything.
''
'' Moving to the global namespace is right for where the instantiation is BUILT
'' and wrong for what its body can SEE.  A generic declared inside a namespace
'' resolves its own namespace's names -- a sibling generic, a const -- by plain
'' unqualified lookup, and once the replay is in the global namespace those names
'' are gone:
''
''     namespace NS
''         const CAP as long = 8
''         type Box( of T ) : as T items( 0 to CAP-1 ) : end type
''     end namespace
''     dim b as NS.Box( of string )     '' CAP not declared
''
'' 'using NS' at the instantiation site hid this for as long as it went unnoticed
'' -- it puts NS on the search chain, so the replay found CAP by accident of the
'' CALLER's scope.  That is exactly backwards: what a generic body can see is
'' fixed where the generic is DECLARED, not where it happens to be used.
''
'' So the declaring namespace chain is pushed onto the search chain for the
'' replay and popped afterwards.  The whole chain up to (not including) global,
'' because a namespace nested in another can reference the outer one's names the
'' same way.  symbNamespaceSearchPush is refcounted, so this composes with a real
'' USING on the same namespace and with nested instantiations.


'' Push/pop every namespace from the generic's declaring namespace up to global.
private sub hDeclNsSearch( byval declns as FBSYMBOL ptr, byval ispush as integer )
	dim as FBSYMBOL ptr glob = @symbGetGlobalNamespc( )
	dim as FBSYMBOL ptr ns = declns

	do while( (ns <> NULL) andalso (ns <> glob) )
		if( ispush ) then
			symbNamespaceSearchPush( ns )
		else
			symbNamespaceSearchPop( ns )
		end if
		ns = symbGetNamespace( ns )
	loop
end sub

sub genEnterGlobalScope _
	( _
		byref gs as FB_GENSCOPE, _
		byval gensym as FBSYMBOL ptr, _
		byval hidelocals as integer _
	)

	dim as FBSYMBOL ptr glob = @symbGetGlobalNamespc( )

	'' captured before the switch, so the pop in genLeaveGlobalScope is exact
	gs.declns = NULL
	if( gensym <> NULL ) then
		gs.declns = symbGetNamespace( gensym )
	end if

	gs.scope     = parser.scope
	gs.currproc  = parser.currproc
	gs.currblock = parser.currblock
	gs.astproc   = ast.proc.curr
	gs.astblock  = ast.currblock
	gs.symtb     = symbGetCurrentSymTb( )
	gs.hashtb    = symbGetCurrentHashTb( )
	gs.ns        = symbGetCurrentNamespc( )

	'' the same values astProcEnd() restores when a procedure body closes
	parser.scope     = FB_MAINSCOPE
	parser.currproc  = env.main.proc
	parser.currblock = env.main.proc
	ast.proc.curr    = ast.proc.head
	ast.currblock    = ast.proc.head

	symbSetCurrentSymTb( @symbGetGlobalTb( ) )
	symbSetCurrentHashTb( @symbGetCompHashTb( glob ) )
	symbSetCurrentNamespc( glob )

	'' The replay is no longer inside the procedure or the block scope the
	'' instantiation was requested from, but that scope's locals are still live
	'' and still in the global hash table, so the "search locals first" pass in
	'' hsymbLookupTypeNS() returns them ahead of this instantiation's type
	'' parameters -- a variable named 't' at the site shadowed 'T' and broke
	'' every 'of T' generic.
	''
	'' Only for replays that parse DECLARATIONS (a type body, a procedure
	'' header): those create no locals of their own, so suppressing the pass
	'' costs nothing.  A member BODY replay must NOT set this -- its own locals
	'' and parameters are exactly what that pass is for, and hiding them made a
	'' local shadowing a field resolve to the field instead.
	gs.hidelocals = hidelocals
	if( hidelocals ) then
		symb.hidelocals += 1
	end if

	'' after the switch: the body is now parsed in the global namespace, and
	'' this is what lets it still see the namespace it was declared in
	hDeclNsSearch( gs.declns, TRUE )
end sub

sub genLeaveGlobalScope( byref gs as FB_GENSCOPE )
	hDeclNsSearch( gs.declns, FALSE )

	if( gs.hidelocals ) then
		assert( symb.hidelocals > 0 )
		symb.hidelocals -= 1
	end if

	symbSetCurrentSymTb( gs.symtb )
	symbSetCurrentHashTb( gs.hashtb )
	symbSetCurrentNamespc( gs.ns )

	parser.scope     = gs.scope
	parser.currproc  = gs.currproc
	parser.currblock = gs.currblock
	ast.proc.curr    = gs.astproc
	ast.currblock    = gs.astblock
end sub

'' Load text into the lexer's DEFTEXT buffer and arm it.
''
'' Mirrors hArgInsertArgA()/hArgAppendLFCHAR() in symb-define.bas: the trailing
'' LF is an end-of-expression marker so the parser cannot read past the end of
'' the text.
private sub hLoadReplayText( byref text as string )
	dim as string t = text + LFCHAR

	if( env.inf.format = FBFILE_FORMAT_ASCII ) then
		DZstrAssign( lex.ctx->deftext, t )
		lex.ctx->defptr = lex.ctx->deftext.data
	else
		DWstrAssign( lex.ctx->deftextw, t )
		lex.ctx->defptrw = lex.ctx->deftextw.data
	end if

	lex.ctx->deflen = len( t )

	'' force a re-read of the current char
	lex.ctx->currchar = cuint( INVALID )
end sub

'' Begin replaying a captured body.
''
'' Returns FALSE if the lexer context stack is exhausted, in which case nothing
'' was pushed and genReplayEnd must NOT be called.
function genReplayBegin _
	( _
		byref st as FB_PARSERSTATE, _
		byref text as string, _
		byval linenum as integer, _
		byval srcfile as zstring ptr _
	) as integer

	'' lex.ctxTB has FB_MAXINCRECLEVEL+1 slots and lexPushCtx does not check;
	'' every other caller pre-checks its own recursion limit, so this one does
	'' too rather than relying on the assert there.
	if( env.includerec >= FB_MAXINCRECLEVEL-1 ) then
		errReport( FB_ERRMSG_RECLEVELTOODEEP )
		return FALSE
	end if

	genSaveState( st )

	'' the replay's symbol lookups must not recycle chains the interrupted
	'' statement still holds -- see symbChainpoolPush
	symbChainpoolPush( )

	lexPushCtx( )
	lexInit( LEX_TKCTX_CONTEXT_GENERIC )

	'' don't let the replay be echoed into the -pp output
	lex.ctx->reclevel += 1

	hLoadReplayText( text )

	'' Report against the generic's own source position, not the instantiation
	'' site.  The captured text carries one LF per original source line, and
	'' the lexer counts them into replayline, so line numbers track the generic
	'' exactly from here on (see lexLineNum).
	lex.ctx->linenum = linenum
	lex.ctx->replayline = linenum
	if( srcfile ) then
		env.inf.name = *srcfile
		env.inf.incfile = srcfile
	end if

	function = TRUE
end function

sub genReplayEnd( byref st as FB_PARSERSTATE )
	lex.ctx->reclevel -= 1
	lexPopCtx( )
	symbChainpoolPop( )
	genRestoreState( st )
end sub

'' The generic's name as the user wrote it.
''
'' id.name is up-cased, so reporting from it makes every diagnostic shout the
'' type name.  The alias holds the source-case form.
function genGenericName( byval gensym as FBSYMBOL ptr ) as zstring ptr
	dim as zstring ptr n = gensym->id.alias
	if( n = NULL ) then
		n = gensym->id.name
	end if
	function = n
end function

'' TypeArgList = '(' OF TypeRef (',' TypeRef)* ')'
''
'' On entry the generic's name has been consumed.  Returns the instantiated
'' type, or NULL on error (the caller fakes a type and carries on).
function cGenericTypeArgs( byval gensym as FBSYMBOL ptr ) as FBSYMBOL ptr

	dim as integer argdtype( 0 to FB_MAXGENERICARGS-1 )
	dim as FBSYMBOL ptr argsubtype( 0 to FB_MAXGENERICARGS-1 )
	dim as integer argcount = 0, dtype = any
	dim as longint lgt = any                        '' cSymbolType takes byref as longint
	dim as FBSYMBOL ptr subtype = any

	function = NULL

	'' '('
	if( lexGetToken( ) <> CHAR_LPRNT ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if
	lexSkipToken( LEXCHECK_POST_SUFFIX )

	'' OF -- matched by text, never a keyword
	if( hMatchIdOrKw( "OF", LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if

	do
		if( argcount >= FB_MAXGENERICARGS ) then
			errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, genGenericName( gensym ) )
			return NULL
		end if

		dtype = FB_DATATYPE_INVALID
		subtype = NULL
		lgt = 0

		'' TypeRef -- recursive, so Vector( of Vector( of long ) ) works
		if( cSymbolType( dtype, subtype, lgt, 0 ) = FALSE ) then
			errReport( FB_ERRMSG_SYNTAXERROR )
			return NULL
		end if

		argdtype( argcount ) = dtype
		argsubtype( argcount ) = subtype
		argcount += 1

		'' ','?
		if( lexGetToken( ) <> CHAR_COMMA ) then
			exit do
		end if
		lexSkipToken( LEXCHECK_POST_SUFFIX )
	loop

	'' ')'
	if( hMatch( CHAR_RPRNT, LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		return NULL
	end if

	function = genInstantiateType( gensym, argdtype(), argsubtype(), argcount )
end function

'' Instantiation cache.
''
'' One entry per (generic, canonical argument list).  Linear: a translation
'' unit has tens of instantiations, not thousands, and this avoids a THASH
'' lifecycle for no measurable gain.
type FB_GENINST
	gensym          as FBSYMBOL ptr
	key             as zstring ptr
	inst            as FBSYMBOL ptr
	nsp             as FBSYMBOL ptr             '' synthetic namespace holding the type-parameter TYPEDEFs
	inprogress      as integer                  '' body still being replayed

	'' where this instantiation was asked for, and how to describe it.  Kept as
	'' private copies because member bodies are replayed later, long after
	'' env.inf has moved on.
	desc            as zstring ptr              '' e.g. "Box( of MyStruct )"
	instfile        as zstring ptr
	instline        as integer
end type

'' One out-of-line member body still owed to one instantiation.
type FB_GENPENDING
	entry           as FB_GENINST ptr
	body            as FB_GENPROC ptr
	done            as integer
end type

type GENINSTCTX
	inited          as integer
	instcount       as integer
	depth           as integer                  '' nested instantiation depth
	list            as TLIST                    '' of FB_GENINST

	pendinited      as integer
	pending         as TLIST                    '' of FB_GENPENDING
	pendcount       as integer                  '' undrained entries; 0 is the fast path
	draining        as integer                  '' genDrainProcBodies is not re-entrant

	'' The generic's source-case name, while its body is being replayed.
	''
	'' An instantiation has to carry its final identity from the moment
	'' symbStructBegin publishes it, not from after the body is parsed: an
	'' EXTENDS clause makes symbStructEnd build RTTI, and hReBuildRtti bakes the
	'' MANGLED NAME into a string constant -- the one oop_istypeof compares at
	'' run time -- while symbGetMangledName caches its result besides.  Tagging
	'' afterwards left every inheriting instantiation mangled as the internal
	'' __FBGENINST, so they collided on one C struct tag and 'is' compared the
	'' wrong strings.
	''
	'' Saved and restored around each replay rather than being a single slot:
	'' 'extends Inner( of T )' instantiates Inner BEFORE the outer struct is
	'' begun, so the inner replay would otherwise consume the outer's tag.
	pendalias       as zstring ptr

	'' The synthetic namespace of the instantiation whose text is being replayed
	'' right now -- the one holding its type-parameter TYPEDEFs -- or NULL
	'' outside every generic replay.  Saved and restored around each replay, so
	'' it always names the INNERMOST one.
	''
	'' Lambdas record it when they are captured and are only drained under the
	'' same value: see genCurrentInstNamespc( ) and lambdaDrainBodies( ).
	curinstns       as FBSYMBOL ptr
end type

dim shared as GENINSTCTX genctx2

'' The instantiation namespace a replay is currently parsing inside, or NULL.
''
'' A lambda body is parsed later than it is written, at the next statement
'' boundary.  A generic body replay has statement boundaries of its own, so
'' without this a lambda written OUTSIDE any generic, but still pending when a
'' generic body was replayed, got its body parsed INSIDE that instantiation --
'' its type parameters in scope ahead of the lambda's own parameters and
'' locals.  'function( byref t as const string ) ... len( t )' then read
'' 'len( T )', the size of the type, and the predicate was always true.
function genCurrentInstNamespc( ) as FBSYMBOL ptr
	function = genctx2.curinstns
end function

'' Internal name of every instantiated struct, inside its own synthetic
'' namespace.  Never user-visible: mangling goes through the ALIAS.
'' Upper-case deliberately: symbAddFwdRef() passes FB_SYMBOPT_PRESERVECASE and
'' documents that it expects an already-up-cased id, while the struct created
'' by the replay goes through the normal up-casing path.  symbCheckFwdRef()
'' resolves by walking the same-name hash chain, so the two must match exactly
'' or the forward reference is never patched and the type stays incomplete.
#define GENINST_NAME "__FBGENINST"

'' Internal name of every instantiated generic PROCEDURE, inside its own
'' synthetic namespace.  Upper-case for the same reason as GENINST_NAME: the
'' replay creates it through the normal up-casing path, and it is looked up
'' again afterwards by exact name.
#define GENPROC_NAME "__FBGENPROC"

'' Give the struct a replay has just begun its permanent identity.
''
'' Called from hTypeAdd immediately after symbStructBegin, which is the last
'' moment before anything can mangle it (see GENINSTCTX.pendalias).  Silent and
'' cheap when no replay is in progress, which is every ordinary TYPE in the
'' module.
sub genTagInstantiation( byval sym as FBSYMBOL ptr )
	if( genctx2.pendalias = NULL ) then
		exit sub
	end if
	if( sym = NULL ) then
		exit sub
	end if
	if( symbIsStruct( sym ) = FALSE ) then
		exit sub
	end if
	if( *symbGetName( sym ) <> GENINST_NAME ) then
		exit sub
	end if

	'' hMangleUdtId() encodes the type arguments as an Itanium I...E template
	'' argument list once this is set, reading them back from the TYPEDEFs in the
	'' synthetic namespace; the ALIAS supplies the readable part, so
	'' Box( of integer ) comes out as 3BoxIiE and not as the internal name.
	sym->attrib or= FB_SYMBATTRIB_GENERICINST

	if( sym->id.alias = NULL ) then
		sym->id.alias = ZstrAllocate( len( *genctx2.pendalias ) )
		*sym->id.alias = *genctx2.pendalias
	end if

	genctx2.pendalias = NULL
end sub

'' The instantiated STRUCT inside a synthetic namespace, or NULL.
''
'' The name is not unique in that hash table: symbAddFwdRef() publishes a
'' FORWARD REFERENCE under the same id so that a self-referential body
'' terminates, and depending on what the body did the forward reference can
'' still be sitting on the chain -- sometimes ahead of the real struct -- after
'' symbStructEnd has run.  Taking chain_->sym unconditionally therefore picks the
'' forward reference at random, which is how an inheriting generic ended up with
'' FB_SYMBATTRIB_GENERICINST set on the wrong symbol: the struct then mangled as
'' the internal __FBGENINST and every instantiation in the module collided on one
'' C struct tag.
private function hFindInstStruct( byval nsp as FBSYMBOL ptr ) as FBSYMBOL ptr
	dim as FBSYMCHAIN ptr c = symbLookupAt( nsp, @GENINST_NAME, FALSE, FALSE )

	while( c )
		dim as FBSYMBOL ptr s = c->sym
		while( s )
			if( symbIsStruct( s ) ) then
				return s
			end if
			s = s->hash.next
		wend
		c = symbChainGetNext( c )
	wend

	function = NULL
end function

private function hCacheLookup _
	( _
		byval gensym as FBSYMBOL ptr, _
		byref key as string _
	) as FBSYMBOL ptr

	if( genctx2.inited = FALSE ) then
		return NULL
	end if

	dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
	while( n )
		if( n->gensym = gensym ) then
			if( *n->key = key ) then
				'' While the body is still being replayed the entry holds a
				'' forward reference, so that a self-referential generic --
				''     type Node( of T ) : as Node( of T ) ptr nxt : end type
				'' -- terminates.  But once symbStructBegin has published the
				'' real struct, a self-reference should get THAT, not the
				'' forward reference.
				''
				'' They are not interchangeable.  Some parameter checks compare
				'' symbol identity rather than the resolved type, and reject the
				'' forward reference even though it prints the same:
				''
				''     declare operator next( byref e as Ctr( of T ) ) as integer
				''     error 142: Invalid parameter type, it must be the same as
				''                the parent TYPE/CLASS
				''
				'' Plain FreeBASIC has no such problem, because inside 'type Ctr'
				'' the name Ctr is already bound to the real symbol.
				if( n->inprogress andalso (n->nsp <> NULL) ) then
					dim as FBSYMBOL ptr s = hFindInstStruct( n->nsp )
					if( s ) then
						return s
					end if
				end if

				return n->inst
			end if
		end if
		n = listGetNext( n )
	wend

	function = NULL
end function

private sub hCacheAdd _
	( _
		byval gensym as FBSYMBOL ptr, _
		byref key as string, _
		byval inst as FBSYMBOL ptr _
	)

	if( genctx2.inited = FALSE ) then
		listInit( @genctx2.list, 64, len( FB_GENINST ), LIST_FLAGS_NOCLEAR )
		genctx2.inited = TRUE
	end if

	dim as FB_GENINST ptr n = listNewNode( @genctx2.list )
	n->gensym = gensym
	n->key = ZstrAllocate( len( key ) )
	*n->key = key
	n->inst = inst
	n->nsp = NULL
	n->inprogress = FALSE

	'' the list is NOCLEAR, so every field has to be set explicitly
	n->desc = NULL
	n->instfile = NULL
	n->instline = 0
end sub

'' Find the cache entry itself, so an in-progress instantiation can be completed
private function hCacheFind _
	( _
		byval gensym as FBSYMBOL ptr, _
		byref key as string _
	) as FB_GENINST ptr

	if( genctx2.inited = FALSE ) then
		return NULL
	end if

	dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
	while( n )
		if( n->gensym = gensym ) then
			if( *n->key = key ) then
				return n
			end if
		end if
		n = listGetNext( n )
	wend

	function = NULL
end function

'' How an instantiated struct is written, e.g. "Box( of long )", and the
'' generic it came from -- or NULL.  For diagnostics and typeof( ): the struct's
'' own name is the internal __FBGENINST inside a namespace named after the
'' mangled key, and messages read '$GEN$$BOX$L$.__FBGENINST' from it.
function genInstDesc _
	( _
		byval inst as FBSYMBOL ptr, _
		byref gensym as FBSYMBOL ptr _
	) as zstring ptr

	gensym = NULL

	if( genctx2.inited = FALSE ) then
		return NULL
	end if

	dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
	while( n )
		if( (n->inst = inst) andalso (n->desc <> NULL) ) then
			gensym = n->gensym
			return n->desc
		end if
		n = listGetNext( n )
	wend

	function = NULL
end function

sub genInstCacheEnd( )
	if( genctx2.inited ) then
		dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
		while( n )
			ZstrFree( n->key )
			n->key = NULL
			if( n->desc ) then
				ZstrFree( n->desc )
				n->desc = NULL
			end if
			if( n->instfile ) then
				ZstrFree( n->instfile )
				n->instfile = NULL
			end if
			n = listGetNext( n )
		wend
		listEnd( @genctx2.list )
		genctx2.inited = FALSE
	end if

	if( genctx2.pendinited ) then
		listEnd( @genctx2.pending )
		genctx2.pendinited = FALSE
		genctx2.pendcount = 0
	end if

	genProcBodyEnd( )
end sub

'' ----------------------------------------------------------------------------
'' Deferred member bodies
'' ----------------------------------------------------------------------------
''
'' A member body cannot be replayed where it is needed.  An instantiation
'' happens in the middle of somebody else's declaration -- 'dim s as Stack( of
'' long )' is mid-statement -- and opening a procedure there is not something the
'' parser supports.  So each (instantiation, body) pair is queued and drained at
'' a module-level statement boundary, which is exactly the position the body
'' would have occupied had the user written it out by hand.
''
'' Deferring also makes declaration order irrelevant, which is the point: a body
'' written after the first instantiation retro-queues for the instantiations that
'' already exist, and one written before is picked up by instantiations made
'' later.

private sub hPendAdd _
	( _
		byval entry as FB_GENINST ptr, _
		byval body as FB_GENPROC ptr _
	)

	if( genctx2.pendinited = FALSE ) then
		listInit( @genctx2.pending, 64, len( FB_GENPENDING ), LIST_FLAGS_NOCLEAR )
		genctx2.pendinited = TRUE
	end if

	'' already queued or already replayed for this instantiation?
	dim as FB_GENPENDING ptr p = listGetHead( @genctx2.pending )
	while( p )
		if( (p->entry = entry) andalso (p->body = body) ) then
			exit sub
		end if
		p = listGetNext( p )
	wend

	p = listNewNode( @genctx2.pending )
	p->entry = entry
	p->body = body
	p->done = FALSE
	genctx2.pendcount += 1
end sub

'' Two callers, distinguished by nsp:
''
''   nsp <> NULL -- an instantiation has just completed; owe it every member body
''                  the generic has so far.  'body' is ignored.
''   nsp  = NULL -- a member body has just been captured; owe it to every
''                  instantiation that already exists.
sub genQueueProcBodies _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval nsp as FBSYMBOL ptr, _
		byval body as FB_GENPROC ptr _
	)

	if( genctx2.inited = FALSE ) then
		exit sub
	end if

	dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
	while( n )
		if( (n->gensym = gensym) andalso (n->inprogress = FALSE) andalso (n->nsp <> NULL) ) then
			if( nsp <> NULL ) then
				if( n->nsp = nsp ) then
					dim as FB_GENPROC ptr b = genGetProcBodies( gensym )
					while( b )
						hPendAdd( n, b )
						b = b->nxt
					wend
				end if
			else
				hPendAdd( n, body )
			end if
		end if
		n = listGetNext( n )
	wend
end sub

'' The keyword that opens (and, after 'end', closes) this kind of procedure.
private function hProcKeyword( byval kindtk as integer ) as string
	select case as const kindtk
	case FB_TK_SUB         : function = "sub"
	case FB_TK_FUNCTION    : function = "function"
	case FB_TK_OPERATOR    : function = "operator"
	case FB_TK_PROPERTY    : function = "property"
	case FB_TK_CONSTRUCTOR : function = "constructor"
	case FB_TK_DESTRUCTOR  : function = "destructor"
	case else              : assert( FALSE ) : function = "sub"
	end select
end function

private sub hReplayProcBody _
	( _
		byval entry as FB_GENINST ptr, _
		byval body as FB_GENPROC ptr _
	)

	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as string text
	dim as integer firstline = any

	'' Two shapes, told apart by whether a separate header was captured:
	''
	''   member body of a generic type
	''     '<kind> __FBGENINST'  +  '.name( ... ) ... end <kind>'
	''   generic procedure
	''     '<kind> __FBGENPROC'  +  '( ... ) as T'  +  ' ... end <kind>'
	''
	'' Either way the captured body already ends with its own terminator, unlike
	'' a type body, so nothing is appended.
	if( body->hdrhead ) then
		'' A global operator has no name: its captured header already starts
		'' with the operator token, which is what stands in for one.
		dim as string nm = GENPROC_NAME
		if( body->op <> INVALID ) then
			nm = ""
		end if

		text = hProcKeyword( body->kindtk ) + " " + nm + _
		       genFlattenTokens( body->hdrhead, firstline ) + LFCHAR + _
		       genFlattenTokens( body->tokhead, firstline )
	else
		text = hProcKeyword( body->kindtk ) + " " + GENINST_NAME + _
		       genFlattenTokens( body->tokhead, firstline )
	end if

	'' The drain point is already at module level, but it may sit inside a
	'' user namespace block; the body belongs to the instantiation, not to
	'' wherever the drain happened to land.
	genEnterGlobalScope( gs, entry->gensym, FALSE )

	'' Bind the type parameters: they are TYPEDEFs living in this
	'' instantiation's synthetic namespace, and __FBGENINST resolves there too.
	symbNestBegin( entry->nsp, FALSE )
	dim as FBSYMBOL ptr savedinstns = genctx2.curinstns
	genctx2.curinstns = entry->nsp

	errPushInstLocation( entry->desc, entry->instfile, entry->instline )

	if( genReplayBegin( st, text, body->srcline, body->srcfile ) ) then
		genctx2.depth += 1
		'' cProgram(), not cProcStmtBegin(): the body's statements, its
		'' compound-statement nesting and its terminator are all ordinary
		'' parsing, and re-implementing that loop here would only let it drift
		'' out of step with the real one.
		cProgram( )
		genctx2.depth -= 1
		genReplayEnd( st )
	end if

	errPopInstLocation( )

	genctx2.curinstns = savedinstns
	symbNestEnd( FALSE )

	genLeaveGlobalScope( gs )
end sub

'' Replay everything owed.  Safe to call at any module-level statement boundary;
'' cheap when there is nothing to do, which is the overwhelmingly common case.
sub genDrainProcBodies( )
	'' fast path -- this runs once per module-level statement
	if( genctx2.pendcount = 0 ) then
		exit sub
	end if

	'' A replayed body may instantiate further generics, which queues more work.
	'' That is handled by looping below, not by re-entering here.
	if( genctx2.draining ) then
		exit sub
	end if

	genctx2.draining = TRUE

	'' Guard against a pathological body that keeps queueing new work.  The
	'' instantiation-depth limit does not cover this: each round is at depth 0.
	dim as integer budget = 0
	dim as integer maxwork = env.clopt.maxinstdepth * 1024

	do
		dim as FB_GENPENDING ptr p = listGetHead( @genctx2.pending )
		dim as integer didwork = FALSE

		while( p )
			if( p->done = FALSE ) then
				p->done = TRUE
				genctx2.pendcount -= 1
				didwork = TRUE

				budget += 1
				if( budget > maxwork ) then
					errReport( FB_ERRMSG_INSTDEPTHTOODEEP )
					errHideFurtherErrors( )
					genctx2.draining = FALSE
					exit sub
				end if

				hReplayProcBody( p->entry, p->body )

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

	genctx2.draining = FALSE
end sub

'' Canonical key for one argument list.
''
'' symbMangleType() is what makes this canonical: an alias of long and long
'' itself produce the same text, so they share one instantiation rather than
'' silently producing two incompatible types.  The same call is what
'' symbAddArrayDescriptorType() uses to key array descriptor types.
private function hArgKey _
	( _
		byval gensym as FBSYMBOL ptr, _
		argdtype() as integer, _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	) as string

	dim as string id

	id = "$" + *symbGetName( gensym ) + "<"
	for i as integer = 0 to argcount-1
		if( i > 0 ) then
			id += ","
		end if
		symbMangleType( id, argdtype(i), argsubtype(i), FB_MANGLEOPT_KEEPTOPCONST )
	next
	symbMangleResetAbbrev( )
	id += ">"

	function = id
end function

'' Rebind a procedure-pointer type argument declared in a procedure's scope to
'' the global prototype with the same signature.  Called once the
'' instantiation is in the global scope (genEnterGlobalScope), which is what
'' makes symbAddProcPtrFromFunction produce the global one.
''
'' A procedure-pointer type written inside a procedure -- 'dim p as function(
'' byref x as T ) as boolean', or a lambda's own type -- gets its prototype in
'' that procedure's scope (symbLookupInternallyMangledSubtype), and the scope
'' deletes it at 'end sub'.  An instantiation outlives that: its member bodies
'' and a generic procedure's body are replayed at the next module-level
'' statement boundary, after the scope is gone, and every later use of the
'' same arguments hits the cache.  The type parameter was then bound to freed
'' memory: 'Aplica( v, lambda )' written inside a generic body compiled
'' Aplica's 'fn( v )' against a garbage prototype -- "Expected ')', found 'v'"
'' -- and in an ordinary procedure it worked only by luck.
''
'' The prototypes are keyed by their mangled signature, so the cache key and
'' the type's identity for overload resolution are unchanged; only its
'' lifetime is.  A signature that names a procedure-LOCAL UDT keeps that UDT's
'' own lifetime problem, as any type argument naming one does (see
'' genEnterGlobalScope).
private sub hGlobalizeProcPtrArgs _
	( _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	)

	for i as integer = 0 to argcount-1
		dim as FBSYMBOL ptr s = argsubtype(i)
		if( s <> NULL ) then
			'' a real procedure is never local: only a procptr prototype is
			if( symbIsProc( s ) andalso symbIsLocal( s ) ) then
				argsubtype(i) = symbAddProcPtrFromFunction( s )
			end if
		end if
	next
end sub

'' Instantiate a generic TYPE|UNION for one argument list.
''
'' The instantiated struct is created inside a synthetic namespace that holds
'' one TYPEDEF per type parameter, bound to the corresponding argument.  The
'' body is then replayed verbatim and 'T' resolves through ordinary namespace
'' lookup -- no textual substitution, which could not spell a local UDT or
'' another instantiation anyway.
''
'' The namespace is marked FB_SYMBATTRIB_GENERICSCOPE and skipped by name
'' mangling; the instantiated struct carries the type arguments in its ALIAS
'' instead, so distinct instantiations get distinct external names.
function genInstantiateType _
	( _
		byval gensym as FBSYMBOL ptr, _
		argdtype() as integer, _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	) as FBSYMBOL ptr

	dim as FBSYMBOL ptr nsp = any, inst = any, prm = any, parent = any, fwd = any
	dim as FBSYMBOLTB ptr symtb = any
	dim as FBHASHTB ptr hashtb = any
	dim as FBSYMCHAIN ptr chain_ = any
	dim as FB_SYMBATTRIB attrib = FB_SYMBATTRIB_NONE
	dim as FB_PROCATTRIB pattrib = FB_PROCATTRIB_NONE
	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as string id, text, nspid, desc
	dim as zstring ptr descz = any
	dim as integer firstline = any

	function = NULL

	'' Runaway guard: a generic whose body instantiates itself with a strictly
	'' larger argument never converges.  Vector( of Vector( of T ) ) is fine and
	'' terminates; this catches the case that does not.
	if( genctx2.depth >= env.clopt.maxinstdepth ) then
		errReportEx( FB_ERRMSG_INSTDEPTHTOODEEP, genGenericName( gensym ) )
		errHideFurtherErrors( )
		return NULL
	end if

	if( argcount <> gensym->gen.paramcount ) then
		errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, genGenericName( gensym ) )
		return NULL
	end if

	id = hArgKey( gensym, argdtype(), argsubtype(), argcount )

	'' Already instantiated?  This is both the cache and the guard against
	'' re-entering a body that is still being parsed.
	''
	'' Kept as an explicit list rather than looked up by symbol name: the
	'' synthetic namespace goes through symbAddNamespace(), which does not pass
	'' FB_SYMBOPT_PRESERVECASE, so its stored name is up-cased -- and the type
	'' argument codes symbMangleType() produces are case-significant, so folding
	'' them would make distinct argument lists collide.
	inst = hCacheLookup( gensym, id )
	if( inst ) then
		return inst
	end if

	'' The namespace name must be DETERMINISTIC, not merely unique.
	''
	'' hMangleNamespace skips GENERICSCOPE, but symbMangleType's STRUCT branch
	'' builds its own namespace chain, so the synthetic namespace still leaks
	'' into the mangled name of a NESTED instantiation.  Deriving the name from
	'' a counter therefore made Box( of Box( of long ) ) mangle differently
	'' depending on what had been instantiated before it, which breaks
	'' RFC-0001 4: the same arguments must mangle identically in every
	'' compilation unit or separate compilation does not link.
	''
	'' Derived from the canonical key instead, with the characters that are
	'' not legal in an identifier folded to '$'.  Phase 4 removes the leak
	'' entirely by mangling type arguments as an Itanium I...E list.
	'' Everything from here to genLeaveGlobalScope builds the instantiation, and
	'' it is built at module level in the global namespace regardless of where
	'' the request came from.
	genEnterGlobalScope( gs, gensym, TRUE )

	nspid = "$gen$"
	for i as integer = 1 to len( id )
		select case id[i-1]
		case asc( "<" ), asc( ">" ), asc( "," ), asc( "$" )
			nspid += "$"
		case else
			nspid += chr( id[i-1] )
		end select
	next
	nsp = symbAddNamespace( strptr( nspid ), NULL )
	if( nsp = NULL ) then
		genLeaveGlobalScope( gs )
		return NULL
	end if
	nsp->attrib or= FB_SYMBATTRIB_GENERICSCOPE

	symbNestBegin( nsp, FALSE )
	dim as FBSYMBOL ptr savedinstns = genctx2.curinstns
	genctx2.curinstns = nsp

	'' Publish a forward reference under the instantiated name BEFORE the body is
	'' replayed, and cache it.  A generic whose body mentions itself --
	''     type Node( of T ) : as Node( of T ) ptr nxt : end type
	'' -- would otherwise start a second instantiation with the same key while the
	'' first is still parsing.  FB's own FWDREF machinery then takes over: the
	'' reference is legal behind a pointer, and symbStructEnd's symbCheckFwdRef
	'' patches every user once the real struct is complete.
	fwd = symbAddFwdRef( @GENINST_NAME )
	hCacheAdd( gensym, id, fwd )
	dim as FB_GENINST ptr entry = hCacheFind( gensym, id )
	if( entry ) then
		entry->inprogress = TRUE
	end if

	'' bind each type parameter -- to a global prototype, if it is a procedure
	'' pointer type from a procedure's scope
	hGlobalizeProcPtrArgs( argsubtype(), argcount )
	prm = gensym->gen.paramhead
	for i as integer = 0 to argcount-1
		symbAddTypedef( symbGetName( prm ), argdtype(i), argsubtype(i), _
		                symbCalcLen( argdtype(i), argsubtype(i) ) )
		prm = prm->next
	next

	'' replay 'type <genericname> <body> end type' inside that namespace
	'' The instantiated struct is deliberately NOT given the generic's name.
	'' symbStructBegin publishes the name before the body is parsed, so naming it
	'' 'Node' would make a self-reference inside the body --
	''     type Node( of T ) : as Node( of T ) ptr nxt : end type
	'' -- resolve to the half-built struct rather than to the generic, and the
	'' '( of T )' would never be consumed.  Under an internal name, 'Node' still
	'' resolves outward to the generic, which re-enters here and gets the
	'' forward reference from the in-progress cache entry.
	''
	'' The external name is unaffected: mangling uses the ALIAS, set below.
	''
	'' TYPE or UNION -- the captured body stops BEFORE its own terminator, so the
	'' keyword is supplied here at both ends.  It used to be hardcoded to 'type',
	'' which silently instantiated every 'union Foo( of T )' as a struct: fields
	'' that should overlap did not, and sizeof came out 16 where the equivalent
	'' plain union is 8.  Wrong code, not a diagnostic -- capture-boundary.bas
	'' declares a generic union but never instantiates one, so nothing caught it.
	dim as string kw = "type"
	if( gensym->gen.kind = FB_GENERICKIND_UNION ) then
		kw = "union"
	end if

	'' The captured body starts immediately after the '( of ... )' clause, so it
	'' may still carry the rest of the HEADER: per cTypeDecl's grammar,
	'' 'alias "..."', 'extends Base' and 'field = n' all live on that line.  They
	'' have to STAY on it -- pushed onto a line of their own, 'extends Shape'
	'' reads as a field declaration and every instantiation of an inheriting
	'' generic failed with a syntax error reported against the generic's own line.
	''
	'' Two tests, because either alone has a hole.  The line number settles it for
	'' ordinary source; a '_' continuation puts the clause on a later line, and
	'' there the leading keyword settles it.  A FIELD actually named
	'' extends/alias/field -- legal in a TYPE without member procedures -- is
	'' always followed by 'as', which none of the three clauses ever is.
	dim as string bodytext = genFlattenTokens( gensym->gen.tokhead, firstline )
	dim as string sep = LFCHAR

	if( gensym->gen.tokhead <> NULL ) then
		if( firstline = gensym->gen.srcline ) then
			sep = " "
		else
			select case ucase( *gensym->gen.tokhead->text )
			case "EXTENDS", "ALIAS", "FIELD"
				dim as FB_GENTOK ptr nx = gensym->gen.tokhead->next
				if( nx = NULL ) then
					sep = " "
				elseif( ucase( *nx->text ) <> "AS" ) then
					sep = " "
				end if
			end select
		end if
	end if

	text = kw + " " + GENINST_NAME + sep + bodytext + LFCHAR + "end " + kw

	'' Readable form for diagnostics, e.g. "Box( of MyStruct )".  Built from the
	'' arguments as written, not from the mangled key, which is unreadable.
	desc = *genGenericName( gensym ) + "( of "
	for i as integer = 0 to argcount-1
		if( i > 0 ) then
			desc += ", "
		end if
		desc += symbTypeToStr( argdtype(i), argsubtype(i) )
	next
	desc += " )"

	descz = ZstrAllocate( len( desc ) )
	*descz = desc

	'' Captured BEFORE genReplayBegin swaps env.inf: the chain must point at the
	'' code that asked for the instantiation, not at the generic's own file.
	''
	'' Kept on the cache entry as well, as private copies: out-of-line member
	'' bodies are replayed at a later statement boundary, by which time env.inf
	'' has moved on, and their chain must still name this instantiation and the
	'' place that asked for it.
	if( entry ) then
		entry->nsp = nsp
		entry->desc = descz
		entry->instfile = ZstrAllocate( len( env.inf.name ) )
		*entry->instfile = env.inf.name
		entry->instline = lexLineNum( )
	end if

	errPushInstLocation( descz, @env.inf.name, lexLineNum( ) )

	dim as zstring ptr savedpend = genctx2.pendalias
	genctx2.pendalias = genGenericName( gensym )

	if( genReplayBegin( st, text, gensym->gen.srcline, gensym->gen.srcfile ) ) then
		genctx2.depth += 1
		cTypeDecl( FB_SYMBATTRIB_NONE )
		genctx2.depth -= 1
		genReplayEnd( st )
	end if

	genctx2.pendalias = savedpend

	errPopInstLocation( )

	genctx2.curinstns = savedinstns
	symbNestEnd( FALSE )

	'' find what the replay built -- the STRUCT, never the forward reference that
	'' may still be sharing the name (see hFindInstStruct)
	inst = hFindInstStruct( nsp )
	if( inst = NULL ) then
		genLeaveGlobalScope( gs )
		return NULL
	end if

	'' hMangleUdtId() encodes the type arguments as an Itanium I...E template
	'' argument list once this is set, reading them back from the TYPEDEFs in
	'' the synthetic namespace.
	inst->attrib or= FB_SYMBATTRIB_GENERICINST

	'' carry the generic's source-case name into the mangled name, so
	'' Box( of integer ) comes out as 3BoxIiE and not as the internal name
	if( inst->id.alias = NULL ) then
		dim as zstring ptr src = gensym->id.alias
		if( src = NULL ) then
			src = gensym->id.name
		end if
		inst->id.alias = ZstrAllocate( len( *src ) )
		*inst->id.alias = *src
	end if

	'' the forward reference has served its purpose; point the cache at the real
	'' struct so later uses get a complete type
	nsp->subtype = inst
	if( entry ) then
		entry->inst = inst
		entry->inprogress = FALSE
	end if

	'' Owe this instantiation every out-of-line member body the generic has so
	'' far.  Bodies written later retro-queue themselves (see cGenericProcDecl).
	genQueueProcBodies( gensym, nsp, NULL )

	genLeaveGlobalScope( gs )

	function = inst
end function

'' Instantiate a generic PROCEDURE for one type-argument list.
''
'' Differs from a type in one way that shapes everything else: the caller needs a
'' CALLABLE symbol immediately, in the middle of an expression, but the body
'' cannot be parsed there.  So the header is replayed now, as an ordinary
'' 'declare', and the body is handed to the same deferred queue that member
'' bodies use.  That is exactly how FreeBASIC already treats a prototype and its
'' out-of-line body, so overload matching between the two needs nothing new.
function genInstantiateProc _
	( _
		byval gensym as FBSYMBOL ptr, _
		argdtype() as integer, _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	) as FBSYMBOL ptr

	dim as FBSYMBOL ptr nsp = any, prm = any, inst = any
	dim as FBSYMCHAIN ptr chain_ = any
	dim as FB_PARSERSTATE st
	dim as FB_GENSCOPE gs
	dim as string id, text, nspid, desc
	dim as zstring ptr descz = any
	dim as integer firstline = any

	function = NULL

	if( genctx2.depth >= env.clopt.maxinstdepth ) then
		errReportEx( FB_ERRMSG_INSTDEPTHTOODEEP, genGenericName( gensym ) )
		errHideFurtherErrors( )
		return NULL
	end if

	if( argcount <> gensym->gen.paramcount ) then
		errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, genGenericName( gensym ) )
		return NULL
	end if

	dim as FB_GENPROC ptr body = genGetProcBodies( gensym )
	if( body = NULL ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if

	id = hArgKey( gensym, argdtype(), argsubtype(), argcount )

	inst = hCacheLookup( gensym, id )
	if( inst ) then
		return inst
	end if

	genEnterGlobalScope( gs, gensym, TRUE )

	nspid = "$gen$"
	for i as integer = 1 to len( id )
		select case id[i-1]
		case asc( "<" ), asc( ">" ), asc( "," ), asc( "$" )
			nspid += "$"
		case else
			nspid += chr( id[i-1] )
		end select
	next

	nsp = symbAddNamespace( strptr( nspid ), NULL )
	if( nsp = NULL ) then
		genLeaveGlobalScope( gs )
		return NULL
	end if
	nsp->attrib or= FB_SYMBATTRIB_GENERICSCOPE

	symbNestBegin( nsp, FALSE )
	dim as FBSYMBOL ptr savedinstns = genctx2.curinstns
	genctx2.curinstns = nsp

	'' bind each type parameter -- to a global prototype, if it is a procedure
	'' pointer type from a procedure's scope
	hGlobalizeProcPtrArgs( argsubtype(), argcount )
	prm = gensym->gen.paramhead
	for i as integer = 0 to argcount-1
		symbAddTypedef( symbGetName( prm ), argdtype(i), argsubtype(i), _
		                symbCalcLen( argdtype(i), argsubtype(i) ) )
		prm = prm->next
	next

	desc = *genGenericName( gensym ) + "( of "
	for i as integer = 0 to argcount-1
		if( i > 0 ) then
			desc += ", "
		end if
		desc += symbTypeToStr( argdtype(i), argsubtype(i) )
	next
	desc += " )"

	descz = ZstrAllocate( len( desc ) )
	*descz = desc

	'' Cache BEFORE the replay, so a generic procedure that calls itself with
	'' the same arguments finds the entry instead of recursing forever.  Unlike
	'' a type there is no forward-reference machinery to fall back on, so the
	'' entry starts out pointing at nothing and is filled in below; a
	'' same-argument self-call during the header replay is not possible anyway,
	'' since a header contains no calls.
	hCacheAdd( gensym, id, NULL )
	dim as FB_GENINST ptr entry = hCacheFind( gensym, id )
	if( entry ) then
		entry->nsp = nsp
		entry->desc = descz
		entry->instfile = ZstrAllocate( len( env.inf.name ) )
		*entry->instfile = env.inf.name
		entry->instline = lexLineNum( )
	end if

	'' EAGER: the prototype, '<kind> __FBGENPROC( params ) [as ret]'.
	''
	'' cProcHeader is called directly rather than replaying a 'declare'
	'' statement through cProgram.  A call site can sit inside another
	'' procedure's body -- one generic procedure calling another, or a generic
	'' type's method calling one -- and a DECLARE is not permitted there:
	'' cProcDecl gates on cCompStmtIsAllowed( FB_CMPSTMT_MASK_DECL ), which the
	'' enclosing FUNCTION stack entry refuses, reporting "Illegal inside a
	'' NAMESPACE block".  cProcHeader itself has no such gate, and the prototype
	'' is all we actually want from that statement.
	dim as string nm = GENPROC_NAME
	if( body->op <> INVALID ) then
		nm = ""
	end if

	text = hProcKeyword( body->kindtk ) + " " + nm + _
	       genFlattenTokens( body->hdrhead, firstline )

	dim as FBSYMBOL ptr hdrproc = NULL

	errPushInstLocation( descz, @env.inf.name, lexLineNum( ) )

	if( genReplayBegin( st, text, body->srcline, body->srcfile ) ) then
		dim as integer is_nested = FALSE
		dim as FB_SYMBATTRIB attrib = FB_SYMBATTRIB_NONE

		'' Give the prototype the same default visibility cProcStmtBegin will
		'' give the body.  Without this the two differ in PUBLIC/PRIVATE, do not
		'' match as prototype-and-definition, and the body is reported as a
		'' duplicate.
		if( env.opt.procpublic ) then
			attrib or= FB_SYMBATTRIB_PUBLIC
		else
			attrib or= FB_SYMBATTRIB_PRIVATE
		end if

		genctx2.depth += 1

		'' Skip the kind keyword the replay text starts with.
		'' lexGetToken() first, to prime the lexer: skipping before the current
		'' token has been read leaves the keyword in place, and cProcHeader then
		'' tries to use 'function' itself as the procedure name.
		if( lexGetToken( ) = body->kindtk ) then
			lexSkipToken( LEXCHECK_POST_SUFFIX )
		end if

		hdrproc = cProcHeader( attrib, 0, is_nested, FB_PROCOPT_ISPROTO, body->kindtk )
		genctx2.depth -= 1
		genReplayEnd( st )
	end if

	errPopInstLocation( )

	genctx2.curinstns = savedinstns
	symbNestEnd( FALSE )

	if( body->op <> INVALID ) then
		'' A global operator is registered in symb.globOpOvlTb, not in any hash
		'' table, so there is no name to look it back up by -- cProcHeader's
		'' return value is the only handle on it.
		inst = hdrproc
		if( inst = NULL ) then
			genLeaveGlobalScope( gs )
			return NULL
		end if

		inst->attrib or= FB_SYMBATTRIB_WEAK

		'' No FB_SYMBATTRIB_GENERICINST here, deliberately.  hMangleProc takes
		'' the operator branch for the id, so the flag would only add an 'I...E'
		'' list, and it is not needed to keep instantiations apart: an operator
		'' living inside the synthetic namespace is C++-mangled (hDoCppMangling
		'' returns TRUE for anything outside the global namespace), so its
		'' parameter types are encoded, and those are exactly what differ.
	else
		chain_ = symbLookupAt( nsp, @GENPROC_NAME, FALSE, FALSE )
		if( chain_ = NULL ) then
			genLeaveGlobalScope( gs )
			return NULL
		end if
		inst = chain_->sym

		'' hMangleProc appends the type arguments as an 'I...E' list once this is
		'' set, and takes the readable part of the name from the ALIAS.  id.name has
		'' to stay __FBGENPROC: the deferred body replay finds its own prototype by
		'' that name.
		inst->attrib or= FB_SYMBATTRIB_GENERICINST

		'' ...and WEAK, so two modules instantiating the same generic procedure
		'' link.  Without it: multiple definition of `_Z5TwiceIiEi'.
		inst->attrib or= FB_SYMBATTRIB_WEAK

		if( inst->id.alias = NULL ) then
			dim as zstring ptr src = genGenericName( gensym )
			inst->id.alias = ZstrAllocate( len( *src ) )
			*inst->id.alias = *src
		end if
	end if

	if( entry ) then
		entry->inst = inst
		entry->inprogress = FALSE
	end if

	'' DEFERRED: the body, at the next module-level statement boundary
	genQueueProcBodies( gensym, nsp, NULL )

	genLeaveGlobalScope( gs )

	function = inst
end function

'' ----------------------------------------------------------------------------
'' Type-argument inference (RFC-0001 5)
'' ----------------------------------------------------------------------------
''
'' Unification of the declared parameter types against the argument types, left
'' to right, first binding wins.  Deliberately minimal, and deliberately without
'' any implicit conversion: Max( 1, 2.0 ) fails rather than silently picking an
'' instantiation the author did not intend.
''
'' The pattern is matched over the CAPTURED HEADER TOKENS rather than over a
'' parsed signature.
''
'' The alternative -- parse the parameter list once at declaration time with each
'' type parameter bound to an opaque placeholder type -- needs those placeholders
'' to have a nominal non-zero size, or every incomplete-type check in the
'' parameter parser fires.  Matching tokens needs no placeholder to exist at all,
'' and the positions RFC-0001 5 admits ('T', 'T ptr') are exactly the ones that
'' are trivial to recognise syntactically.  Anything it cannot match simply fails
'' inference and asks for explicit arguments, which is what the RFC prescribes
'' for that case anyway.

type FB_GENPARAMPAT
	paramidx        as integer                  '' which type parameter, or -1
	ptrlevels       as integer                  '' 'T ptr ptr' -> 2
	matched         as integer                  '' pattern understood at all?

	'' A nested position, 'G( of T )'.  Needed by generic global operators,
	'' whose parameters are almost always of that shape -- there is no way to
	'' write explicit type arguments at an operator's use site, so a nested
	'' position is the only thing inference has to go on.
	''
	'' nestedcount = 0 means this is not one.  Otherwise the argument is
	'' required to be an instantiation of a generic whose name is nestedname,
	'' and nestedidx(i) says which of THIS generic's type parameters the
	'' instantiation's i-th type argument binds (-1 = a concrete type, which
	'' binds nothing and is not checked).
	nestedcount     as integer
	nestedname      as string
	nestedidx       ( 0 to FB_MAXGENERICARGS-1 ) as integer
end type

'' Which type parameter does this name refer to?  -1 if none.
private function hTypeParamIndex _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval text as zstring ptr _
	) as integer

	dim as FBSYMBOL ptr prm = gensym->gen.paramhead
	dim as integer i = 0
	dim as string want = ucase( *text )

	while( prm )
		if( ucase( *symbGetName( prm ) ) = want ) then
			return i
		end if
		prm = prm->next
		i += 1
	wend

	function = -1
end function

'' 'G( of A, B )' at the current header token.
''
'' On success fills the nested half of pat and returns the token holding the
'' closing ')', so the caller can carry on past the whole clause without the
'' outer paren-depth counter ever seeing it.  Returns NULL if this is not a
'' nested generic position, or is one this does not model.
private function hScanNested _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval n as FB_GENTOK ptr, _
		byref p as FB_GENPARAMPAT _
	) as FB_GENTOK ptr

	dim as FB_GENTOK ptr w = n->next

	if( w = NULL ) then
		return NULL
	end if
	if( *w->text <> "(" ) then
		return NULL
	end if

	w = w->next
	if( w = NULL ) then
		return NULL
	end if
	if( ucase( *w->text ) <> "OF" ) then
		return NULL
	end if

	p.nestedname = ucase( *n->text )
	p.nestedcount = 0

	do
		w = w->next
		if( w = NULL ) then
			return NULL
		end if

		if( p.nestedcount >= FB_MAXGENERICARGS ) then
			return NULL
		end if

		'' Only a single-token argument is modelled: either one of this
		'' generic's own type parameters, or a concrete type that binds nothing.
		'' Anything else -- a further nesting, a pointer, a qualified name --
		'' is not something inference can invert, so the whole position is
		'' refused rather than guessed at.
		p.nestedidx( p.nestedcount ) = hTypeParamIndex( gensym, w->text )
		p.nestedcount += 1

		w = w->next
		if( w = NULL ) then
			return NULL
		end if

		if( *w->text = ")" ) then
			exit do
		end if

		if( *w->text <> "," ) then
			return NULL
		end if
	loop

	p.matched = TRUE

	function = w
end function

'' Walk the captured header and describe each parameter's declared type.
''
'' Returns the number of parameters found.  Tokens look like
''     ( byval a as T , byref b as T ptr )
'' so parameters split on commas at paren depth 1, and a parameter's type is
'' whatever follows its last 'as' at that depth.
private function hScanParamPatterns _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval hdr as FB_GENTOK ptr, _
		pat() as FB_GENPARAMPAT _
	) as integer

	dim as FB_GENTOK ptr n = hdr
	dim as integer depth = 0, count = 0
	dim as integer sawas = FALSE

	'' skip to just inside the opening '('
	while( n andalso (*n->text <> "(") )
		n = n->next
	wend
	if( n = NULL ) then
		return 0
	end if
	depth = 1
	n = n->next

	pat( 0 ).paramidx = -1
	pat( 0 ).ptrlevels = 0
	pat( 0 ).matched = FALSE
	pat( 0 ).nestedcount = 0

	while( n )
		dim as string t = *n->text

		if( t = "(" ) then
			depth += 1
			'' 'arr() as T' -- an array parameter; not inferred here
			if( (depth = 2) andalso (sawas = FALSE) ) then
				pat( count ).matched = FALSE
			end if
		elseif( t = ")" ) then
			depth -= 1
			if( depth = 0 ) then
				exit while
			end if
		elseif( (depth = 1) andalso (t = ",") ) then
			count += 1
			if( count >= FB_MAXGENERICARGS ) then
				exit while
			end if
			pat( count ).paramidx = -1
			pat( count ).ptrlevels = 0
			pat( count ).matched = FALSE
			pat( count ).nestedcount = 0
			sawas = FALSE
		elseif( depth = 1 ) then
			if( ucase( t ) = "AS" ) then
				sawas = TRUE
				'' a fresh type starts here; forget anything seen before
				pat( count ).paramidx = -1
				pat( count ).ptrlevels = 0
				pat( count ).matched = FALSE
				pat( count ).nestedcount = 0
			elseif( sawas ) then
				select case ucase( t )
				case "PTR", "POINTER"
					if( pat( count ).matched ) then
						pat( count ).ptrlevels += 1
					end if
				case "CONST"
					'' ignore; CONST-ness does not participate
				case else
					if( (pat( count ).paramidx = -1) andalso (pat( count ).nestedcount = 0) ) then
						dim as integer idx = hTypeParamIndex( gensym, strptr( t ) )
						if( idx >= 0 ) then
							pat( count ).paramidx = idx
							pat( count ).matched = TRUE
						else
							'' 'G( of ... )' -- a nested generic position.
							dim as FB_GENTOK ptr nn = hScanNested( gensym, n, pat( count ) )
							if( nn <> NULL ) then
								'' the whole clause is consumed here, so the
								'' outer depth counter never sees its parens
								n = nn
							else
								'' a concrete type, or something more involved;
								'' it binds nothing
								pat( count ).matched = FALSE
							end if
						end if
					else
						'' more tokens after the type name that this does not
						'' model -- refuse to guess
						pat( count ).matched = FALSE
					end if
				end select
			end if
		end if

		n = n->next
	wend

	'' an empty parameter list has no parameters, not one
	if( (count = 0) andalso (pat( 0 ).paramidx = -1) andalso (pat( 0 ).matched = FALSE) andalso (sawas = FALSE) ) then
		return 0
	end if

	function = count + 1
end function

'' The generic an instantiated struct came from, or NULL if it is not one.
''
'' Recovered by walking the instantiation cache rather than from a field on the
'' symbol: FBSYMBOL is a union of per-class records and its size was pinned in
'' Phase 1, and this is asked only while resolving a generic global operator,
'' which is rare.
private function hGenericOfInst( byval inst as FBSYMBOL ptr ) as FBSYMBOL ptr
	if( genctx2.inited = FALSE ) then
		return NULL
	end if

	dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
	while( n )
		if( n->inst = inst ) then
			return n->gensym
		end if
		n = listGetNext( n )
	wend

	function = NULL
end function

'' The idx'th type argument of an instantiation.
''
'' Read back from the TYPEDEFs in its synthetic namespace -- those bindings ARE
'' the type arguments, in declaration order.  The same recovery
'' hMangleTemplateArgs() does for the 'I...E' list.
private function hInstTypeArg _
	( _
		byval inst as FBSYMBOL ptr, _
		byval idx as integer, _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr _
	) as integer

	dim as FBSYMBOL ptr nsp = symbGetNamespace( inst )
	if( nsp = NULL ) then
		return FALSE
	end if
	if( symbIsGenericScope( nsp ) = FALSE ) then
		return FALSE
	end if

	dim as FBSYMBOL ptr t = symbGetCompSymbTb( nsp ).head
	dim as integer i = 0

	while( t <> NULL )
		if( symbIsTypedef( t ) ) then
			if( i = idx ) then
				dtype = symbGetFullType( t )
				subtype = symbGetSubtype( t )
				return TRUE
			end if
			i += 1
		end if
		t = t->next
	wend

	function = FALSE
end function

'' Unify one parameter pattern against one argument type.
''
'' Returns FALSE only on a real conflict -- two positions binding the same type
'' parameter to different types, or an argument whose shape does not fit the
'' pattern.  A pattern that binds nothing (a concrete parameter type) succeeds
'' without doing anything.
private function hBindPattern _
	( _
		byref p as FB_GENPARAMPAT, _
		byval argdtype as integer, _
		byval argsubtype as FBSYMBOL ptr, _
		bounddtype() as integer, _
		boundsubtype() as FBSYMBOL ptr, _
		isbound() as integer _
	) as integer

	if( p.matched = FALSE ) then
		return TRUE
	end if

	dim as integer dtype = argdtype
	dim as FBSYMBOL ptr subtype = argsubtype

	'' 'T ptr' binds T to the pointee
	for k as integer = 1 to p.ptrlevels
		if( typeIsPtr( dtype ) = 0 ) then
			return FALSE
		end if
		dtype = typeDeref( dtype )
	next

	'' CONST-ness of the argument does not participate
	dtype = typeUnsetIsConst( dtype )

	'' 'G( of T )' -- the argument has to be an instantiation of G, and then
	'' each of ITS type arguments binds in turn.
	if( p.nestedcount > 0 ) then
		if( typeGetDtOnly( dtype ) <> FB_DATATYPE_STRUCT ) then
			return FALSE
		end if
		if( subtype = NULL ) then
			return FALSE
		end if

		dim as FBSYMBOL ptr g = hGenericOfInst( subtype )
		if( g = NULL ) then
			return FALSE
		end if

		'' Matched by name.  The alternative -- resolving the header token to a
		'' symbol -- would have to be done at the use site, where the name may
		'' resolve differently than it did at the declaration.  Either way the
		'' failure mode is the same and harmless: a wrong match instantiates
		'' something whose parameters then do not fit, and overload resolution
		'' reports an ordinary type mismatch.
		if( ucase( *genGenericName( g ) ) <> p.nestedname ) then
			return FALSE
		end if

		if( g->gen.paramcount <> p.nestedcount ) then
			return FALSE
		end if

		for i as integer = 0 to p.nestedcount-1
			if( p.nestedidx( i ) < 0 ) then
				continue for
			end if

			dim as integer adtype = any
			dim as FBSYMBOL ptr asubtype = any

			if( hInstTypeArg( subtype, i, adtype, asubtype ) = FALSE ) then
				return FALSE
			end if

			dim as integer q = p.nestedidx( i )
			if( isbound( q ) = FALSE ) then
				bounddtype( q ) = adtype
				boundsubtype( q ) = asubtype
				isbound( q ) = TRUE
			elseif( (bounddtype( q ) <> adtype) orelse (boundsubtype( q ) <> asubtype) ) then
				return FALSE
			end if
		next

		return TRUE
	end if

	'' The one normalisation inference performs: a string LITERAL has type
	'' zstring (or a fixed-length string), and neither can be a BYVAL
	'' parameter, so Max( "abc", "abd" ) would infer 'Max( of zstring )' and
	'' then fail deep inside the instantiated body with "Illegal
	'' specification, at parameter 1".
	''
	'' This is not the implicit conversion RFC-0001 5 rules out.  That rule
	'' is about never silently choosing between two types the author
	'' actually wrote -- Max( 1, 2.0 ) must fail rather than promote.  Here
	'' both arguments are string literals and 'string' is the only type the
	'' author could have meant.
	if( p.ptrlevels = 0 ) then
		select case typeGetDtOnly( dtype )
		case FB_DATATYPE_CHAR, FB_DATATYPE_FIXSTR
			dtype = FB_DATATYPE_STRING
			subtype = NULL
		end select
	end if

	dim as integer pi = p.paramidx
	if( pi < 0 ) then
		return TRUE
	end if

	if( isbound( pi ) = FALSE ) then
		bounddtype( pi ) = dtype
		boundsubtype( pi ) = subtype
		isbound( pi ) = TRUE
	else
		'' No implicit conversion: two positions binding the same parameter
		'' to different types is an error, not a promotion.
		''
		'' Max( v + v, v ) is rejected, and that is correct rather than a
		'' shortcoming: FreeBASIC promotes 'long + long' to the native
		'' INTEGER, so those two arguments really ARE integer and long.
		'' Measured, after two wrong guesses at a non-existent bug -- the
		'' argument dtypes were 8 (INTEGER) and 11 (LONG).
		if( (bounddtype( pi ) <> dtype) orelse (boundsubtype( pi ) <> subtype) ) then
			return FALSE
		end if
	end if

	function = TRUE
end function

'' ----------------------------------------------------------------------------
'' Generic global operators
'' ----------------------------------------------------------------------------

'' Try to instantiate one generic global operator for these operand types.
''
'' Silent throughout.  An operator that does not fit is not an error: the same
'' AST_OP may have ordinary overloads, or none, and the caller's normal
'' diagnostics are the right ones.  Instantiating is idempotent -- the second
'' identical 'x + y' hits the instantiation cache.
private sub hTryOneGlobalOp _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval ldtype as integer, _
		byval lsubtype as FBSYMBOL ptr, _
		byval rdtype as integer, _
		byval rsubtype as FBSYMBOL ptr _
	)

	static as FB_GENPARAMPAT pat( 0 to FB_MAXGENERICARGS-1 )
	dim as integer bounddtype( 0 to FB_MAXGENERICARGS-1 )
	dim as FBSYMBOL ptr boundsubtype( 0 to FB_MAXGENERICARGS-1 )
	dim as integer isbound( 0 to FB_MAXGENERICARGS-1 )

	dim as FB_GENPROC ptr body = genGetProcBodies( gensym )
	if( body = NULL ) then
		exit sub
	end if

	dim as integer argcount = iif( rdtype = FB_DATATYPE_INVALID, 1, 2 )
	dim as integer paramcount = hScanParamPatterns( gensym, body->hdrhead, pat() )

	if( paramcount <> argcount ) then
		exit sub
	end if

	for i as integer = 0 to gensym->gen.paramcount-1
		isbound( i ) = FALSE
	next

	if( hBindPattern( pat( 0 ), ldtype, lsubtype, bounddtype(), boundsubtype(), isbound() ) = FALSE ) then
		exit sub
	end if

	if( argcount = 2 ) then
		if( hBindPattern( pat( 1 ), rdtype, rsubtype, bounddtype(), boundsubtype(), isbound() ) = FALSE ) then
			exit sub
		end if
	end if

	for i as integer = 0 to gensym->gen.paramcount-1
		if( isbound( i ) = FALSE ) then
			exit sub
		end if
	next

	genInstantiateProc( gensym, bounddtype(), boundsubtype(), gensym->gen.paramcount )
end sub

sub genTryInstantiateGlobalOp _
	( _
		byval op as integer, _
		byval ldtype as integer, _
		byval lsubtype as FBSYMBOL ptr, _
		byval rdtype as integer, _
		byval rsubtype as FBSYMBOL ptr _
	)

	dim as FB_GENOP ptr g = genGetGenericOps( )

	'' the fast path, and the overwhelmingly common one: no generic operators
	'' were ever declared, so every BOP in the module costs one NULL test
	while( g )
		if( g->op = op ) then
			hTryOneGlobalOp( g->gensym, ldtype, lsubtype, rdtype, rsubtype )
		end if
		g = g->nxt
	wend
end sub

'' TypeArgList at a call site: '( OF TypeRef (',' TypeRef)* ')'
''
'' On entry the procedure's name has been consumed and the current token is the
'' '('.  On exit the whole clause is consumed, so the caller continues at the
'' real argument list exactly as for an ordinary call.
function cGenericProcArgs( byval gensym as FBSYMBOL ptr ) as FBSYMBOL ptr

	dim as integer argdtype( 0 to FB_MAXGENERICARGS-1 )
	dim as FBSYMBOL ptr argsubtype( 0 to FB_MAXGENERICARGS-1 )
	dim as integer argcount = 0, dtype = any
	dim as longint lgt = any                        '' cSymbolType takes byref as longint
	dim as FBSYMBOL ptr subtype = any

	function = NULL

	if( lexGetToken( ) <> CHAR_LPRNT ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if
	lexSkipToken( LEXCHECK_POST_SUFFIX )

	if( hMatchIdOrKw( "OF", LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if

	do
		if( argcount >= FB_MAXGENERICARGS ) then
			errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, genGenericName( gensym ) )
			return NULL
		end if

		dtype = FB_DATATYPE_INVALID
		subtype = NULL
		lgt = 0

		if( cSymbolType( dtype, subtype, lgt, 0 ) = FALSE ) then
			errReport( FB_ERRMSG_SYNTAXERROR )
			return NULL
		end if

		argdtype( argcount ) = dtype
		argsubtype( argcount ) = subtype
		argcount += 1

		if( lexGetToken( ) <> CHAR_COMMA ) then
			exit do
		end if
		lexSkipToken( LEXCHECK_POST_SUFFIX )
	loop

	if( hMatch( CHAR_RPRNT, LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		return NULL
	end if

	function = genInstantiateProc( gensym, argdtype(), argsubtype(), argcount )
end function

'' An inferred call: 'Swap2( x, y )', with no type arguments written.
''
'' The argument expressions are parsed HERE, before the procedure exists, which
'' is the whole difficulty: cProcArgList needs a procedure symbol up front, and
'' inference needs the argument types up front.  They are parsed once, kept, and
'' handed to the instantiated procedure afterwards -- cProcArgList already
'' supports exactly that, since it feeds any pre-existing arg_list entries
'' through astNewARG before parsing anything itself.
''
'' Parentheses are required.  A paren-less statement call ('Swap2 x, y') would
'' have to parse an argument list with no idea where it ends, and the RFC's
'' inference examples are all parenthesised.
function cGenericProcInferredCall _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval gensym as FBSYMBOL ptr, _
		byval options as FB_PARSEROPT _
	) as ASTNODE ptr

	static as FB_GENPARAMPAT pat( 0 to FB_MAXGENERICARGS-1 )
	dim as ASTNODE ptr argexpr( 0 to FB_MAXGENERICARGS-1 )
	dim as integer argdtype( 0 to FB_MAXGENERICARGS-1 )
	dim as FBSYMBOL ptr argsubtype( 0 to FB_MAXGENERICARGS-1 )

	dim as integer bounddtype( 0 to FB_MAXGENERICARGS-1 )
	dim as FBSYMBOL ptr boundsubtype( 0 to FB_MAXGENERICARGS-1 )
	dim as integer isbound( 0 to FB_MAXGENERICARGS-1 )

	dim as integer argcount = 0, paramcount = any

	function = NULL

	dim as FB_GENPROC ptr body = genGetProcBodies( gensym )
	if( body = NULL ) then
		errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if

	if( lexGetToken( ) <> CHAR_LPRNT ) then
		errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if
	lexSkipToken( )

	'' argument expressions
	if( lexGetToken( ) <> CHAR_RPRNT ) then
		do
			if( argcount >= FB_MAXGENERICARGS ) then
				errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
				return NULL
			end if

			dim as ASTNODE ptr e = cExpression( )
			if( e = NULL ) then
				errReport( FB_ERRMSG_EXPECTEDEXPRESSION )
				return NULL
			end if

			argexpr( argcount ) = e
			argdtype( argcount ) = astGetFullType( e )
			argsubtype( argcount ) = astGetSubtype( e )
			argcount += 1

			if( lexGetToken( ) <> CHAR_COMMA ) then
				exit do
			end if
			lexSkipToken( )
		loop
	end if

	if( hMatch( CHAR_RPRNT ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		return NULL
	end if

	'' unify
	for i as integer = 0 to gensym->gen.paramcount-1
		isbound( i ) = FALSE
	next

	paramcount = hScanParamPatterns( gensym, body->hdrhead, pat() )

	if( paramcount <> argcount ) then
		errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
		return NULL
	end if

	for i as integer = 0 to argcount-1
		if( hBindPattern( pat( i ), argdtype( i ), argsubtype( i ), _
		                  bounddtype(), boundsubtype(), isbound() ) = FALSE ) then
			errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
			return NULL
		end if
	next

	for i as integer = 0 to gensym->gen.paramcount-1
		if( isbound( i ) = FALSE ) then
			errReportEx( FB_ERRMSG_CANTINFERTYPEARGS, genGenericName( gensym ) )
			return NULL
		end if
	next

	dim as FBSYMBOL ptr proc = genInstantiateProc( gensym, bounddtype(), boundsubtype(), _
	                                               gensym->gen.paramcount )
	if( proc = NULL ) then
		return NULL
	end if

	'' Build the call from the arguments already parsed.  Same sequence
	'' cProcArgList uses for its pre-defined args.
	dim as ASTNODE ptr procexpr = astNewCALL( proc, NULL )

	for i as integer = 0 to argcount-1
		if( astNewARG( procexpr, argexpr( i ) ) = NULL ) then
			astDelTree( procexpr )
			return astBuildFakeCall( proc )
		end if
	next

	procexpr = astBuildByrefResultDeref( procexpr )

	function = procexpr
end function
