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
'' parser.stmt is deliberately absent: it is a stack with its own push/pop
'' discipline (cCompStmtPush/Pop), so instead of copying it we assert on the way
'' out that the replay left it at the depth it found it.
type FB_PARSERSTATE
	'' parser
	options         as FB_PARSEROPT
	prntcnt         as integer
	nsprefix        as FBSYMCHAIN ptr
	mangling        as FB_MANGLING
	stage           as uinteger
	scope           as uinteger
	currproc        as FBSYMBOL ptr
	currblock       as FBSYMBOL ptr
	ctx_dtype       as integer
	ctxsym          as FBSYMBOL ptr
	have_eq         as integer
	stmtdepth       as integer

	'' ast
	astproc         as ASTNODE ptr
	astblock        as ASTNODE ptr
	doemit          as integer
	typeinicount    as integer

	'' input file
	inf             as FBFILE

	'' error context: the one-error-per-statement filter keys off this, and a
	'' replay must not make the caller's next real error disappear
	laststmt        as integer
end type

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
	st.stmtdepth    = parser.stmt.cnt

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

	ast.proc.curr   = st.astproc
	ast.currblock   = st.astblock
	ast.doemit      = st.doemit
	ast.typeinicount = st.typeinicount

	env.inf         = st.inf

	errSetLastStmt( st.laststmt )

	'' A replay that opened a compound statement and never closed it would
	'' leave the caller's stack skewed, and the failure would surface far away
	'' from the cause.
	assert( parser.stmt.cnt = st.stmtdepth )
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

	lexPushCtx( )
	lexInit( LEX_TKCTX_CONTEXT_GENERIC )

	'' don't let the replay be echoed into the -pp output
	lex.ctx->reclevel += 1

	hLoadReplayText( text )

	'' Report against the generic's own source position, not the instantiation
	'' site.  UPDATE_LINENUM was taught to keep counting for this context kind,
	'' and the captured text carries one LF per original source line, so line
	'' numbers track the generic exactly from here on.
	lex.ctx->linenum = linenum
	if( srcfile ) then
		env.inf.name = *srcfile
		env.inf.incfile = srcfile
	end if

	function = TRUE
end function

sub genReplayEnd( byref st as FB_PARSERSTATE )
	lex.ctx->reclevel -= 1
	lexPopCtx( )
	genRestoreState( st )
end sub

'' The generic's name as the user wrote it.
''
'' id.name is up-cased, so reporting from it makes every diagnostic shout the
'' type name.  The alias holds the source-case form.
private function hGenericName( byval gensym as FBSYMBOL ptr ) as zstring ptr
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
	dim as integer argcount = 0, dtype = any, lgt = any
	dim as FBSYMBOL ptr subtype = any

	function = NULL

	'' '('
	if( lexGetToken( ) <> CHAR_LPRNT ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, hGenericName( gensym ) )
		return NULL
	end if
	lexSkipToken( LEXCHECK_POST_SUFFIX )

	'' OF -- matched by text, never a keyword
	if( hMatchIdOrKw( "OF", LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReportEx( FB_ERRMSG_GENERICNEEDSTYPEARGS, hGenericName( gensym ) )
		return NULL
	end if

	do
		if( argcount >= FB_MAXGENERICARGS ) then
			errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, hGenericName( gensym ) )
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
	inprogress      as integer                  '' body still being replayed
end type

type GENINSTCTX
	inited          as integer
	instcount       as integer
	depth           as integer                  '' nested instantiation depth
	list            as TLIST                    '' of FB_GENINST
end type

dim shared as GENINSTCTX genctx2

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
	n->inprogress = FALSE
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

sub genInstCacheEnd( )
	if( genctx2.inited ) then
		dim as FB_GENINST ptr n = listGetHead( @genctx2.list )
		while( n )
			ZstrFree( n->key )
			n->key = NULL
			n = listGetNext( n )
		wend
		listEnd( @genctx2.list )
		genctx2.inited = FALSE
	end if
end sub

'' Internal name of every instantiated struct, inside its own synthetic
'' namespace.  Never user-visible: mangling goes through the ALIAS.
'' Upper-case deliberately: symbAddFwdRef() passes FB_SYMBOPT_PRESERVECASE and
'' documents that it expects an already-up-cased id, while the struct created
'' by the replay goes through the normal up-casing path.  symbCheckFwdRef()
'' resolves by walking the same-name hash chain, so the two must match exactly
'' or the forward reference is never patched and the type stays incomplete.
#define GENINST_NAME "__FBGENINST"

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
	dim as string id, text, nspid, desc
	dim as zstring ptr descz = any
	dim as integer firstline = any

	function = NULL

	'' Runaway guard: a generic whose body instantiates itself with a strictly
	'' larger argument never converges.  Vector( of Vector( of T ) ) is fine and
	'' terminates; this catches the case that does not.
	if( genctx2.depth >= env.clopt.maxinstdepth ) then
		errReportEx( FB_ERRMSG_INSTDEPTHTOODEEP, hGenericName( gensym ) )
		errHideFurtherErrors( )
		return NULL
	end if

	if( argcount <> gensym->gen.paramcount ) then
		errReportEx( FB_ERRMSG_WRONGTYPEARGCOUNT, hGenericName( gensym ) )
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
		return NULL
	end if
	nsp->attrib or= FB_SYMBATTRIB_GENERICSCOPE

	symbNestBegin( nsp, FALSE )

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

	'' bind each type parameter
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
	text = "type " + GENINST_NAME + LFCHAR + _
	       genFlattenTokens( @gensym->gen, firstline ) + LFCHAR + "end type"

	'' Readable form for diagnostics, e.g. "Box( of MyStruct )".  Built from the
	'' arguments as written, not from the mangled key, which is unreadable.
	desc = *hGenericName( gensym ) + "( of "
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
	errPushInstLocation( descz, @env.inf.name, lexLineNum( ) )

	if( genReplayBegin( st, text, gensym->gen.srcline, gensym->gen.srcfile ) ) then
		genctx2.depth += 1
		cTypeDecl( FB_SYMBATTRIB_NONE )
		genctx2.depth -= 1
		genReplayEnd( st )
	end if

	errPopInstLocation( )

	symbNestEnd( FALSE )

	'' find what the replay built
	chain_ = symbLookupAt( nsp, @GENINST_NAME, FALSE, FALSE )
	if( chain_ = NULL ) then
		return NULL
	end if
	inst = chain_->sym

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

	function = inst
end function
