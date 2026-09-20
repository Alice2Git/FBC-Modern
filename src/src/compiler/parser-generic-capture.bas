'' Generic body capture.
''
'' A generic declaration produces no code.  Its body is retained verbatim as a
'' token chain and replayed once per instantiation, with the type parameters
'' bound as TYPEDEFs in a synthetic namespace.  This module is the capture half
'' of that: it reads the tokens between a generic's header and its terminator,
'' records them, and checks that the block structure balances.
''
'' Why tokens and not raw source text: there is no facility in the lexer for
'' recording the source span covered by a range of tokens.  currline is lossy
'' and only alive under -g, lexReadLine handles a single line, and seeking
'' env.inf gives pre-preprocessor text from a file that may already be closed.
''
'' Why not FB_DEFTOK / hReadMacroText: the macro reader drops comments,
'' collapses whitespace runs, eats '##' and stringizes '#param'.  All of that
'' is right for a macro and wrong for a body that has to be re-parsed as
'' declarations.  FB_GENTOK also carries a per-node line number, because
'' UPDATE_LINENUM is suppressed while the lexer is replaying from DEFTEXT.
''
'' chng: aug/2026 written

#include once "fb.bi"
#include once "fbint.bi"
#include once "parser.bi"
#include once "list.bi"

'' Lexer flags used while capturing.
''
'' NOSUFFIX  - keep '$', '#', '&' etc. as separate tokens rather than folding
''             them into the preceding one, so re-emitting is faithful without
''             having to reconstruct suffixes.  Same reason hReadMacroText uses
''             it.
'' NOQUOTES  - keep the quotes on string literals so they lex back as literals.
''
'' Deliberately NOT LEXCHECK_NOSYMBOL: it forces every identifier to FB_TK_ID
'' (lex.bas:1670), which would hide the END/TYPE/UNION keywords that terminate
'' the body.
''
'' Deliberately NOT LEXCHECK_NODEFINE: RFC-0001 says the preprocessor runs
'' first, as today, so macros expand while the body is being read.
#define GENTOK_FLAGS (LEXCHECK_NOSUFFIX or LEXCHECK_NOQUOTES)

type GENCAPTURECTX
	inited          as integer
	toklist         as TLIST                    '' of FB_GENTOK
end type

dim shared as GENCAPTURECTX genctx

private sub hInit( )
	if( genctx.inited = FALSE ) then
		listInit( @genctx.toklist, 512, len( FB_GENTOK ), LIST_FLAGS_NOCLEAR )
		genctx.inited = TRUE
	end if
end sub

sub genCaptureEnd( )
	if( genctx.inited ) then
		'' free the per-token text; the nodes themselves belong to the list
		dim as FB_GENTOK ptr n = listGetHead( @genctx.toklist )
		while( n )
			if( n->text ) then
				ZstrFree( n->text )
				n->text = NULL
			end if
			n = listGetNext( n )
		wend

		listEnd( @genctx.toklist )
		genctx.inited = FALSE
	end if
end sub

'' Append one token node to a chain.
''
'' The head/tail pair is passed byref rather than the owning record, because the
'' same chain shape is used for a generic's type body (FBS_GENERIC) and for each
'' of its out-of-line member bodies (FB_GENPROC).
private function hAddTokTo _
	( _
		byref head as FB_GENTOK ptr, _
		byref tail as FB_GENTOK ptr, _
		byval text as const zstring ptr, _
		byval linenum as integer _
	) as FB_GENTOK ptr

	dim as FB_GENTOK ptr n = any

	hInit( )

	n = listNewNode( @genctx.toklist )
	n->type = FB_DEFTOK_TYPE_TEX
	n->text = ZstrAllocate( len( *text ) )
	*n->text = *text
	n->linenum = linenum
	n->next = NULL
	n->prev = tail

	if( tail ) then
		tail->next = n
	else
		head = n
	end if
	tail = n

	function = n
end function

private function hAddTok _
	( _
		byval gen as FBS_GENERIC ptr, _
		byval text as const zstring ptr, _
		byval linenum as integer _
	) as FB_GENTOK ptr

	function = hAddTokTo( gen->tokhead, gen->toktail, text, linenum )
end function

'' Is the TYPE|UNION at the current token opening an inner UDT, rather than
'' naming a field?
''
'' This mirrors hTypeBody() in parser-decl-struct.bas exactly -- if the two
'' disagree, capture consumes the wrong number of tokens and every declaration
'' after the generic is misparsed.
private function hIsInnerUdtOpen( ) as integer
	select case as const lexGetLookAhead( 1, GENTOK_FLAGS )
	'' 'type' <eol> -- anonymous inner UDT
	case FB_TK_EOL, FB_TK_EOF, FB_TK_COMMENT, FB_TK_REM, FB_TK_FIELD
		return TRUE

	'' 'type:' -- separator before an inner UDT, unless it is a bitfield
	case FB_TK_STMTSEP
		return (lexGetLookAheadClass( 2, GENTOK_FLAGS ) <> FB_TKCLASS_NUMLITERAL)

	'' 'type as ...' -- a field literally named 'type'
	case FB_TK_AS
		return FALSE

	'' otherwise a named nested TYPE|UNION
	case else
		return TRUE
	end select
end function

'' Is the END at the current token closing a block, rather than naming a field?
'' Mirrors the 'isn't it a field called "end"?' test in hTypeBody().
private function hIsBlockEnd( ) as integer
	select case lexGetLookAhead( 1, GENTOK_FLAGS )
	case FB_TK_AS, CHAR_LPRNT, FB_TK_STMTSEP
		return FALSE
	case else
		return TRUE
	end select
end function

'' Capture the body of a generic TYPE|UNION, up to and including its
'' terminating END TYPE|UNION.
''
'' On entry the current token is the first token of the body (the header,
'' including the (of ...) clause, has already been consumed).  On exit the
'' terminator has been consumed, so the caller continues after 'end type'
'' exactly as cTypeDecl would.
''
'' Returns FALSE and reports at the generic's own line if the body does not
'' balance -- this is the declaration-time structural pre-scan.  Names, types,
'' operators and arity are not checked here; they are checked at instantiation,
'' where the error carries the instantiation chain.
function genCaptureTypeBody _
	( _
		byval sym as FBSYMBOL ptr, _
		byval startline as integer _
	) as integer

	dim as FBS_GENERIC ptr gen = @sym->gen
	dim as integer depth = any, tk = any

	gen->tokhead = NULL
	gen->toktail = NULL

	'' the generic's own TYPE counts as depth 1; capture until it closes
	depth = 1

	do
		tk = lexGetToken( GENTOK_FLAGS )

		select case as const tk
		case FB_TK_EOF
			'' ran off the end of the file without closing
			errReportEx( FB_ERRMSG_UNBALANCEDGENERICBODY, _
			             symbGetName( sym ), startline )
			return FALSE

		'' comments are not part of the body; skip to end of line
		case FB_TK_COMMENT, FB_TK_REM
			do
				lexSkipToken( GENTOK_FLAGS )
				select case lexGetToken( GENTOK_FLAGS )
				case FB_TK_EOL, FB_TK_EOF
					exit do
				end select
			loop
			continue do

		case FB_TK_END
			if( hIsBlockEnd( ) ) then
				select case lexGetLookAhead( 1, GENTOK_FLAGS )
				case FB_TK_TYPE, FB_TK_UNION, FB_TK_ENUM
					depth -= 1

					if( depth = 0 ) then
						'' the generic's own terminator: consume 'end' and
						'' 'type'|'union' without recording, so the captured
						'' body is exactly the members
						lexSkipToken( GENTOK_FLAGS )
						lexSkipToken( GENTOK_FLAGS )
						exit do
					end if

					'' An inner block closing.  Both tokens must be recorded
					'' and consumed together: consuming only 'end' would leave
					'' the TYPE|UNION|ENUM to be re-examined on the next pass
					'' and counted as opening a new block.
					hAddTok( gen, lexGetText( ), lexLineNum( ) )
					lexSkipToken( GENTOK_FLAGS )
					hAddTok( gen, lexGetText( ), lexLineNum( ) )
					lexSkipToken( GENTOK_FLAGS )
					continue do
				end select
			end if

		case FB_TK_TYPE, FB_TK_UNION
			if( hIsInnerUdtOpen( ) ) then
				depth += 1
			end if

		case FB_TK_ENUM
			'' 'enum as ...' would be a field named 'enum'
			if( lexGetLookAhead( 1, GENTOK_FLAGS ) <> FB_TK_AS ) then
				depth += 1
			end if

		end select

		'' record it
		hAddTok( gen, lexGetText( ), lexLineNum( ) )

		lexSkipToken( GENTOK_FLAGS )
	loop

	function = TRUE
end function

'' TypeParamList = '(' OF ID (',' ID)* ')'
''
'' On entry the current token is the '(' and the token after it is the
'' contextual keyword 'of'.  Type parameters are recorded as placeholder
'' symbols chained through .next; at instantiation each is re-created as a
'' TYPEDEF bound to the corresponding argument.
private function hTypeParamList( byval sym as FBSYMBOL ptr ) as integer

	dim as FBS_GENERIC ptr gen = @sym->gen
	dim as FBSYMBOL ptr prm = any, tail = NULL, walk = any
	dim as zstring * FB_MAXNAMELEN+1 id

	gen->paramhead = NULL
	gen->paramcount = 0

	'' '('
	lexSkipToken( LEXCHECK_POST_SUFFIX )

	'' OF -- matched by text, never a keyword
	if( hMatchIdOrKw( "OF", LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDTYPEPARAM )
		return FALSE
	end if

	do
		'' ID
		if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
			errReport( FB_ERRMSG_EXPECTEDTYPEPARAM )
			return FALSE
		end if

		lexEatToken( @id )

		'' already used by this generic?
		walk = gen->paramhead
		while( walk )
			if( ucase( *symbGetName( walk ) ) = ucase( id ) ) then
				errReportEx( FB_ERRMSG_DUPTYPEPARAM, id )
				return FALSE
			end if
			walk = walk->next
		wend

		'' A placeholder, deliberately not added to any hash table: inside the
		'' generic's body 'T' must not resolve to anything until instantiation
		'' binds it.
		prm = symbNewSymbol( FB_SYMBOPT_NONE, NULL, NULL, NULL, _
		                     FB_SYMBCLASS_TYPEDEF, id, NULL, _
		                     FB_DATATYPE_VOID, NULL, _
		                     FB_SYMBATTRIB_NONE, FB_PROCATTRIB_NONE )
		if( prm = NULL ) then
			return FALSE
		end if
		prm->next = NULL

		if( tail ) then
			tail->next = prm
		else
			gen->paramhead = prm
		end if
		tail = prm
		gen->paramcount += 1

		'' ','?
		if( lexGetToken( ) <> CHAR_COMMA ) then
			exit do
		end if
		lexSkipToken( LEXCHECK_POST_SUFFIX )
	loop

	'' ')'
	if( hMatch( CHAR_RPRNT, LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		return FALSE
	end if

	function = TRUE
end function

'' type|union ID '(' OF ... ')' ... end type|union
''
'' Called from cTypeDecl() once it has read the name and seen that a '(' with
'' 'of' after it follows.  Everything from after the ')' up to (but not
'' including) the terminating END TYPE|UNION is captured verbatim, so an
'' EXTENDS or ALIAS clause on the header is captured too and simply re-parsed
'' at instantiation.
sub cGenericTypeDecl _
	( _
		byval attrib as FB_SYMBATTRIB, _
		byval id as const zstring ptr, _
		byval isunion as integer _
	)

	dim as FBSYMBOL ptr sym = any
	dim as integer startline = lexLineNum( )

	'' the source-case name is kept as the alias, so instantiations mangle the
	'' way a hand-written type of the same name would
	sym = symbNewSymbol( FB_SYMBOPT_DOHASH, NULL, NULL, NULL, _
	                     FB_SYMBCLASS_GENERIC, id, id, _
	                     FB_DATATYPE_VOID, NULL, _
	                     attrib, FB_PROCATTRIB_NONE )

	if( sym = NULL ) then
		errReportEx( FB_ERRMSG_DUPDEFINITION, id )
		'' error recovery: swallow the body so the rest of the file still parses
		hSkipCompound( iif( isunion, FB_TK_UNION, FB_TK_TYPE ) )
		exit sub
	end if

	sym->gen.kind = iif( isunion, FB_GENERICKIND_UNION, FB_GENERICKIND_TYPE )
	sym->gen.tokhead = NULL
	sym->gen.toktail = NULL
	sym->gen.instances = NULL
	sym->gen.srcline = startline
	'' A private copy in the file's ORIGINAL case.  env.inf.incfile is interned
	'' and may be up-cased, which would make every diagnostic from an instantiated
	'' body shout the file name; env.inf.name itself is a reused fixed buffer that
	'' is overwritten as includes pop.
	sym->gen.srcfile = ZstrAllocate( len( env.inf.name ) )
	*sym->gen.srcfile = env.inf.name

	if( hTypeParamList( sym ) = FALSE ) then
		'' error recovery: swallow the body
		hSkipCompound( iif( isunion, FB_TK_UNION, FB_TK_TYPE ) )
		exit sub
	end if

	genCaptureTypeBody( sym, startline )

end sub

'' ----------------------------------------------------------------------------
'' Out-of-line member bodies
'' ----------------------------------------------------------------------------

'' Every member body captured so far, in source order per generic.  Kept here
'' rather than in FBS_GENERIC so that FBSYMBOL does not grow: the union member is
'' already the widest in the symbol, and a translation unit has tens of generics,
'' not thousands.
type GENPROCCTX
	inited          as integer
	list            as TLIST                    '' of FB_GENPROC
end type

dim shared as GENPROCCTX genprocctx

'' Every generic global operator declared so far.  A plain list, walked once per
'' candidate BOP -- there are single digits of these in a translation unit, and
'' the walk only happens for an operator that has no ordinary overload yet.
type GENOPCTX
	inited          as integer
	head            as FB_GENOP ptr
	tail            as FB_GENOP ptr
	list            as TLIST                    '' of FB_GENOP
end type

dim shared as GENOPCTX genopctx

function genGetGenericOps( ) as FB_GENOP ptr
	function = genopctx.head
end function

sub genProcBodyEnd( )
	if( genprocctx.inited ) then
		dim as FB_GENPROC ptr n = listGetHead( @genprocctx.list )
		while( n )
			if( n->srcfile ) then
				ZstrFree( n->srcfile )
				n->srcfile = NULL
			end if
			n = listGetNext( n )
		wend
		listEnd( @genprocctx.list )
		genprocctx.inited = FALSE
	end if

	if( genopctx.inited ) then
		listEnd( @genopctx.list )
		genopctx.inited = FALSE
		genopctx.head = NULL
		genopctx.tail = NULL
	end if
end sub

'' The bodies belonging to one generic, oldest first
function genGetProcBodies( byval gensym as FBSYMBOL ptr ) as FB_GENPROC ptr
	if( genprocctx.inited = FALSE ) then
		return NULL
	end if

	dim as FB_GENPROC ptr n = listGetHead( @genprocctx.list )
	while( n )
		if( n->gensym = gensym ) then
			return n
		end if
		n = listGetNext( n )
	wend

	function = NULL
end function

private function hAddProcBody _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval kindtk as integer _
	) as FB_GENPROC ptr

	if( genprocctx.inited = FALSE ) then
		listInit( @genprocctx.list, 32, len( FB_GENPROC ), LIST_FLAGS_NOCLEAR )
		genprocctx.inited = TRUE
	end if

	dim as FB_GENPROC ptr n = listNewNode( @genprocctx.list )
	n->gensym  = gensym
	n->kindtk  = kindtk
	n->hdrhead = NULL
	n->hdrtail = NULL
	n->tokhead = NULL
	n->toktail = NULL
	n->op      = INVALID
	n->srcline = lexLineNum( )
	n->nxt     = NULL

	'' see cGenericTypeDecl: a private copy, in the file's original case
	n->srcfile = ZstrAllocate( len( env.inf.name ) )
	*n->srcfile = env.inf.name

	'' chain onto the tail of this generic's list, so bodies replay in source
	'' order and a later body cannot shadow an earlier one
	dim as FB_GENPROC ptr head = genGetProcBodies( gensym )
	if( head <> n ) then
		while( head->nxt )
			head = head->nxt
		wend
		head->nxt = n
	end if

	function = n
end function

'' Does the current token name a generic?  Cheap: the lexer has already attached
'' the symbol chain, so this costs no extra look-ahead.
function genLookupGeneric( ) as FBSYMBOL ptr
	dim as FBSYMCHAIN ptr chain_ = lexGetSymChain( )

	while( chain_ <> NULL )
		dim as FBSYMBOL ptr sym = chain_->sym
		while( sym <> NULL )
			if( symbIsGeneric( sym ) ) then
				return sym
			end if
			sym = sym->hash.next
		wend
		chain_ = symbChainGetNext( chain_ )
	wend

	function = NULL
end function

'' Is the parser looking at 'Foo( of ...' where Foo is a generic?
''
'' The symbol test comes first and the text peek second, deliberately.  Peeking
'' two tokens ahead drives the lexer further than this path otherwise would,
'' which disturbs macro expansion -- doing it unconditionally broke ordinary
'' macro calls elsewhere.
function genIsGenericMemberProc( ) as integer
	if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
		return FALSE
	end if

	dim as FBSYMBOL ptr gensym = genLookupGeneric( )
	if( gensym = NULL ) then
		return FALSE
	end if

	'' Only a generic TYPE/UNION has member bodies.  Without this,
	'' re-declaring a generic PROCEDURE would take the member-body path and
	'' fail asking for a '.', instead of reporting the duplicate.
	select case gensym->gen.kind
	case FB_GENERICKIND_TYPE, FB_GENERICKIND_UNION
	case else
		return FALSE
	end select

	if( lexGetLookAhead( 1 ) <> CHAR_LPRNT ) then
		return FALSE
	end if

	function = (ucase( *lexGetLookAheadText( 2 ) ) = "OF")
end function

'' Is the parser looking at 'Name( of T )( ... )' -- a generic PROCEDURE
'' declaration?
''
'' Unlike a generic type, 'sub Name(' is ordinary syntax, so this has to be
'' told apart from a normal parameter list.  The trap is that 'of' is not a
'' keyword and never will be (RFC-0001 guarantees existing code keeps
'' compiling), so
''
''     sub foo( of as long )
''
'' declares a PARAMETER called 'of' and must keep working.  Verified against the
'' compiler before this was written: that, 'byval of as long', 'dim of as long'
'' and even 'sub of( ... )' all compile today.
''
'' One more token settles it.  A type parameter list always has an identifier
'' after 'of'; a parameter named 'of' is followed by 'as', ',' or ')'.
'' At a call site, with the procedure's name already consumed: is this
'' 'Name( of long )( ... )' or the inferred 'Name( ... )'?
''
'' One token of text look-ahead, and only when a '(' is actually there, so an
'' inferred call costs nothing extra.
function genHasExplicitTypeArgs( ) as integer
	if( lexGetToken( ) <> CHAR_LPRNT ) then
		return FALSE
	end if

	function = (ucase( *lexGetLookAheadText( 1 ) ) = "OF")
end function

'' Same question as genHasExplicitTypeArgs, but asked BEFORE the name has been
'' consumed -- the expression parser dispatches on the symbol while the
'' identifier is still current.
function genHasExplicitTypeArgsAfterId( ) as integer
	if( lexGetLookAhead( 1 ) <> CHAR_LPRNT ) then
		return FALSE
	end if

	function = (ucase( *lexGetLookAheadText( 2 ) ) = "OF")
end function

function genIsGenericProcDecl( ) as integer
	if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
		return FALSE
	end if

	if( lexGetLookAhead( 1 ) <> CHAR_LPRNT ) then
		return FALSE
	end if

	if( ucase( *lexGetLookAheadText( 2 ) ) <> "OF" ) then
		return FALSE
	end if

	function = (lexGetLookAheadClass( 3 ) = FB_TKCLASS_IDENTIFIER)
end function

'' '(' OF ID (',' ID)* ')' on an out-of-line body, checked against the generic's
'' own declaration.
''
'' The names must match positionally.  Binding is by name -- the type parameters
'' live as TYPEDEFs in the instantiation's synthetic namespace, under the names
'' the declaration used -- so a body that renames them would simply fail to
'' resolve them, with a confusing error.  Rejecting it up front says what is
'' actually wrong.
private function hCheckProcTypeParams( byval gensym as FBSYMBOL ptr ) as integer

	dim as FBSYMBOL ptr prm = gensym->gen.paramhead
	dim as zstring * FB_MAXNAMELEN+1 id
	dim as integer count = 0

	'' '('
	lexSkipToken( LEXCHECK_POST_SUFFIX )

	'' OF -- matched by text, never a keyword
	if( hMatchIdOrKw( "OF", LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReportEx( FB_ERRMSG_EXPECTEDTYPEPARAM, genGenericName( gensym ) )
		return FALSE
	end if

	do
		if( lexGetClass( ) <> FB_TKCLASS_IDENTIFIER ) then
			errReport( FB_ERRMSG_EXPECTEDTYPEPARAM )
			return FALSE
		end if

		lexEatToken( @id )
		count += 1

		if( prm = NULL ) then
			errReportEx( FB_ERRMSG_TYPEPARAMMISMATCH, genGenericName( gensym ) )
			return FALSE
		end if

		if( ucase( *symbGetName( prm ) ) <> ucase( id ) ) then
			errReportEx( FB_ERRMSG_TYPEPARAMMISMATCH, genGenericName( gensym ) )
			return FALSE
		end if

		prm = prm->next

		'' ','?
		if( lexGetToken( ) <> CHAR_COMMA ) then
			exit do
		end if
		lexSkipToken( LEXCHECK_POST_SUFFIX )
	loop

	'' ')'
	if( hMatch( CHAR_RPRNT, LEXCHECK_POST_SUFFIX ) = FALSE ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		return FALSE
	end if

	if( count <> gensym->gen.paramcount ) then
		errReportEx( FB_ERRMSG_TYPEPARAMMISMATCH, genGenericName( gensym ) )
		return FALSE
	end if

	function = TRUE
end function

'' Capture a procedure body up to and including its terminating END <kind>.
''
'' Procedures cannot nest in FreeBASIC, but LAMBDAS can sit inside one, and a
'' lambda of the same kind as the generic ends with the very same
'' 'END FUNCTION' / 'END SUB'. Stopping at the first one cut the generic's body
'' short at the lambda's terminator: the rest of the body -- 'return ...', the
'' real 'end function' -- was then parsed at module level ("error 53: Illegal
'' outside a ... FUNCTION ... block", "error 112: END SUB or FUNCTION without
'' SUB or FUNCTION"), even for a generic that was never instantiated.
''
'' So lambda openings are counted, and an END SUB|FUNCTION at depth > 0 closes
'' a lambda rather than the generic. What counts as an opening is decided by
'' lambdaOpensHere( ), shared with the lambda capture itself: a procedure-
'' pointer declaration ('dim cb as sub( )') and a result assignment
'' ('function = x') mention the keyword without opening anything, which is
'' exactly why counting every SUB|FUNCTION -- what hSkipCompound does for error
'' recovery -- would be wrong here.
private function hCaptureProcBody _
	( _
		byval body as FB_GENPROC ptr, _
		byval gensym as FBSYMBOL ptr, _
		byval startline as integer _
	) as integer

	#define hAddProcTok( b, t, l ) hAddTokTo( (b)->tokhead, (b)->toktail, t, l )

	'' lambdas open inside the body, not yet closed
	dim as integer depth = 0

	'' the two tokens before the current one, for lambdaOpensHere( )
	dim as integer prevtk = INVALID, prevprevtk = INVALID

	do
		select case as const lexGetToken( GENTOK_FLAGS )
		case FB_TK_EOF
			errReportEx( FB_ERRMSG_UNBALANCEDGENERICBODY, _
			             genGenericName( gensym ), startline )
			return FALSE

		'' comments are not part of the body -- and an 'end sub' inside one
		'' must not terminate it
		case FB_TK_COMMENT, FB_TK_REM
			do
				lexSkipToken( GENTOK_FLAGS )
				select case lexGetToken( GENTOK_FLAGS )
				case FB_TK_EOL, FB_TK_EOF
					exit do
				end select
			loop
			continue do

		case FB_TK_END
			dim as integer kind = lexGetLookAhead( 1, GENTOK_FLAGS )

			if( depth > 0 ) then
				select case kind
				case FB_TK_SUB, FB_TK_FUNCTION
					'' a lambda closing -- record 'end' and the kind keyword
					'' together, so the keyword is never re-examined as an opening
					depth -= 1
					hAddProcTok( body, lexGetText( ), lexLineNum( ) )
					lexSkipToken( GENTOK_FLAGS )
					hAddProcTok( body, lexGetText( ), lexLineNum( ) )
					lexSkipToken( GENTOK_FLAGS )
					prevprevtk = FB_TK_END
					prevtk = kind
					continue do
				end select

			elseif( kind = body->kindtk ) then
				'' record 'end' and the kind keyword together and stop
				hAddProcTok( body, lexGetText( ), lexLineNum( ) )
				lexSkipToken( GENTOK_FLAGS )
				hAddProcTok( body, lexGetText( ), lexLineNum( ) )
				lexSkipToken( GENTOK_FLAGS )
				exit do
			end if

		case FB_TK_SUB, FB_TK_FUNCTION
			if( lambdaOpensHere( prevtk, prevprevtk, GENTOK_FLAGS ) ) then
				depth += 1
			end if

		end select

		prevprevtk = prevtk
		prevtk = lexGetToken( GENTOK_FLAGS )
		hAddProcTok( body, lexGetText( ), lexLineNum( ) )
		lexSkipToken( GENTOK_FLAGS )
	loop

	function = TRUE
end function

'' SUB|FUNCTION|... ID '(' OF ... ')' '.' ID ... END SUB|FUNCTION|...
''
'' Called from cProcStmtBegin() once the kind keyword has been consumed and the
'' current token is seen to name a generic followed by '( of'.  Returns TRUE if
'' the statement was consumed here.
''
'' Capture starts at the token AFTER the ')' -- the '.' before the member name --
'' so replaying only needs '<kind> __FBGENINST' pasted in front.  Re-parsing the
'' 'Foo( of T )' part instead would mean teaching cParentId to accept a type
'' argument list, for no gain: inside an instantiation 'T' is already bound, so
'' the header can only ever name the instantiation being replayed into.
function cGenericProcDecl( byval tk as integer ) as integer

	dim as FBSYMBOL ptr gensym = genLookupGeneric( )
	dim as integer startline = lexLineNum( )

	if( gensym = NULL ) then
		return FALSE
	end if

	'' skip the generic's name
	lexSkipToken( LEXCHECK_NOPERIOD or LEXCHECK_POST_SUFFIX )

	if( hCheckProcTypeParams( gensym ) = FALSE ) then
		hSkipCompound( tk )
		return TRUE
	end if

	dim as FB_GENPROC ptr body = hAddProcBody( gensym, tk )

	if( hCaptureProcBody( body, gensym, startline ) = FALSE ) then
		return TRUE
	end if

	'' A body may be written after the type has already been instantiated, so
	'' every existing instantiation retro-queues it.  Instantiations made later
	'' pick it up from the generic's list instead.
	genQueueProcBodies( gensym, NULL, body )

	function = TRUE
end function

'' ----------------------------------------------------------------------------
'' Generic procedures
'' ----------------------------------------------------------------------------

'' Capture the header: everything from the '(' of the parameter list up to, but
'' not including, the end of the declaration line.
''
'' Stops at EOL or ':' so that a one-liner --
''     sub f( of T )( byval x as T ) : print x : end sub
'' -- splits in the same place a multi-line declaration does.
''
'' At DEPTH 0 only. Inside the parameter list both may belong to a default
'' value that is a lambda, which carries ':' between its statements and real
'' EOLs when written over several lines:
''     function G( of T )( byval f as Fn = function( byval x as long ) as long : return x + 1 : end function ) as long
'' Ending the header at that ':' cut the declaration in half -- "error 3:
'' Expected End-of-Line, found ')'" -- and the remains of the parameter list
'' were then parsed as statements. Both forms work outside generics, so the
'' capture is what has to keep up.
private sub hCaptureProcHeader( byval d as FB_GENPROC ptr )
	'' open '(' and '[' -- a lambda's capture list can hold neither, but it
	'' nests the same way and costs nothing to track
	dim as integer depth = 0

	do
		select case lexGetToken( GENTOK_FLAGS )
		case FB_TK_EOF
			exit do

		case FB_TK_EOL, FB_TK_STMTSEP
			if( depth = 0 ) then
				exit do
			end if

		case FB_TK_COMMENT, FB_TK_REM
			if( depth = 0 ) then
				exit do
			end if

			'' inside the list: not part of the header, and an 'end sub' in
			'' one must not be mistaken for anything -- drop it
			do
				lexSkipToken( GENTOK_FLAGS )
				select case lexGetToken( GENTOK_FLAGS )
				case FB_TK_EOL, FB_TK_EOF
					exit do
				end select
			loop
			continue do

		case CHAR_LPRNT, CHAR_LBRACKET
			depth += 1

		case CHAR_RPRNT, CHAR_RBRACKET
			if( depth > 0 ) then
				depth -= 1
			end if
		end select

		hAddTokTo( d->hdrhead, d->hdrtail, lexGetText( ), lexLineNum( ) )
		lexSkipToken( GENTOK_FLAGS )
	loop
end sub

'' SUB|FUNCTION|... ID '(' OF ... ')' ParamList ... END SUB|FUNCTION|...
''
'' Called from cProcStmtBegin() once the kind keyword has been consumed and the
'' current token is seen to be 'Name( of Id'.  Returns TRUE if the statement was
'' consumed here.
function cGenericProcDeclNew( byval tk as integer ) as integer

	dim as FBSYMBOL ptr sym = any
	dim as integer startline = lexLineNum( )
	dim as zstring * FB_MAXNAMELEN+1 id

	lexEatToken( @id, LEXCHECK_NOPERIOD or LEXCHECK_POST_SUFFIX )

	'' the source-case name is kept as the alias, exactly as for a generic type
	sym = symbNewSymbol( FB_SYMBOPT_DOHASH, NULL, NULL, NULL, _
	                     FB_SYMBCLASS_GENERIC, @id, @id, _
	                     FB_DATATYPE_VOID, NULL, _
	                     FB_SYMBATTRIB_NONE, FB_PROCATTRIB_NONE )

	if( sym = NULL ) then
		errReportEx( FB_ERRMSG_DUPDEFINITION, @id )
		hSkipCompound( tk )
		return TRUE
	end if

	sym->gen.kind = FB_GENERICKIND_PROC
	sym->gen.tokhead = NULL
	sym->gen.toktail = NULL
	sym->gen.instances = NULL
	sym->gen.srcline = startline
	sym->gen.srcfile = ZstrAllocate( len( env.inf.name ) )
	*sym->gen.srcfile = env.inf.name

	if( hTypeParamList( sym ) = FALSE ) then
		hSkipCompound( tk )
		return TRUE
	end if

	'' A generic procedure is modelled as a generic owning exactly ONE body, so
	'' the deferred-replay machinery built for member bodies carries it
	'' unchanged -- including the retro-queueing that makes declaration order
	'' irrelevant.
	dim as FB_GENPROC ptr d = hAddProcBody( sym, tk )
	d->srcline = startline

	hCaptureProcHeader( d )

	'' Drop the EOL or ':' that ended the header.  An EOL token's text is a bare
	'' LF, and the body's line structure is rebuilt from the recorded line
	'' numbers anyway, so keeping it would only add a stray blank line.
	select case lexGetToken( GENTOK_FLAGS )
	case FB_TK_EOL, FB_TK_STMTSEP
		lexSkipToken( GENTOK_FLAGS )
	end select

	'' the rest, terminator included, replayed later as the body
	if( hCaptureProcBody( d, sym, startline ) = FALSE ) then
		return TRUE
	end if

	function = TRUE
end function

'' ----------------------------------------------------------------------------
'' Generic global operators
'' ----------------------------------------------------------------------------

'' 'operator <op>( of T )( ... )'.
''
'' Same three-token test as genIsGenericProcDecl, and for the same reason: 'of'
'' is not a keyword, so 'operator +( of as Box, b as Box )' declares a parameter
'' called 'of' and has to keep compiling.  A type parameter list always has an
'' identifier after 'of'.
''
'' One token is enough for the operator's own name because every operator that
'' can be global is spelled with exactly one token.  The multi-token forms --
'' '[]', 'new[]', 'delete[]' -- are all self ops, and a self op is always a
'' method, which this path rejects below.
function genIsGenericOpDecl( ) as integer
	'' 'operator Box( of T ).+=' is a member body of a generic type and matches
	'' the same shape; it is handled before this is reached, and excluded here
	'' too so the two tests cannot both claim the statement.
	if( lexGetClass( ) = FB_TKCLASS_IDENTIFIER ) then
		return FALSE
	end if

	if( lexGetLookAhead( 1 ) <> CHAR_LPRNT ) then
		return FALSE
	end if

	if( ucase( *lexGetLookAheadText( 2 ) ) <> "OF" ) then
		return FALSE
	end if

	function = (lexGetLookAheadClass( 3 ) = FB_TKCLASS_IDENTIFIER)
end function

'' OPERATOR <op> '(' OF ... ')' ParamList ... END OPERATOR
''
'' Called from cProcStmtBegin() once OPERATOR has been consumed.  Returns TRUE if
'' the statement was consumed here.
''
'' Modelled exactly like cGenericProcDeclNew -- a generic owning one body, header
'' replayed eagerly and body deferred -- with one difference: the operator token
'' itself is prepended to the captured header, because there is no name to paste
'' in front at replay time.
function cGenericOpDecl( byval tk as integer ) as integer

	dim as FBSYMBOL ptr sym = any
	dim as integer startline = lexLineNum( )
	dim as string optext = *lexGetText( )
	dim as integer op = any

	op = cOperator( TRUE )

	select case op
	case INVALID, _
	     AST_OP_ANDALSO, AST_OP_ANDALSO_SELF, _
	     AST_OP_ORELSE, AST_OP_ORELSE_SELF
		errReport( FB_ERRMSG_EXPECTEDOPERATOR )
		hSkipCompound( tk )
		return TRUE
	end select

	'' A self op is always a method, and there is no parent type here to be a
	'' method of.  'operator Box( of T ).+=' is the way to write that, and it
	'' already works -- it is an ordinary member body of a generic type.
	if( astGetOpIsSelf( op ) ) then
		errReport( FB_ERRMSG_OPMUSTBEAMETHOD )
		hSkipCompound( tk )
		return TRUE
	end if

	'' The internal name is never looked up -- the symbol is not hashed -- but
	'' hArgKey() builds the instantiation cache key and the synthetic namespace
	'' name out of it, so it has to be a legal identifier.  The readable form
	'' goes in the ALIAS, which is what every diagnostic prints.
	dim as string internalid = "__FBGENOP" + str( op )
	dim as string readable = "operator " + optext

	sym = symbNewSymbol( FB_SYMBOPT_NONE, NULL, NULL, NULL, _
	                     FB_SYMBCLASS_GENERIC, strptr( internalid ), strptr( readable ), _
	                     FB_DATATYPE_VOID, NULL, _
	                     FB_SYMBATTRIB_NONE, FB_PROCATTRIB_NONE )

	if( sym = NULL ) then
		hSkipCompound( tk )
		return TRUE
	end if

	sym->gen.kind = FB_GENERICKIND_PROC
	sym->gen.tokhead = NULL
	sym->gen.toktail = NULL
	sym->gen.instances = NULL
	sym->gen.srcline = startline
	sym->gen.srcfile = ZstrAllocate( len( env.inf.name ) )
	*sym->gen.srcfile = env.inf.name

	if( hTypeParamList( sym ) = FALSE ) then
		hSkipCompound( tk )
		return TRUE
	end if

	dim as FB_GENPROC ptr d = hAddProcBody( sym, tk )
	d->srcline = startline
	d->op = op

	'' the operator token leads the header, standing in for the name
	hAddTokTo( d->hdrhead, d->hdrtail, strptr( optext ), startline )

	hCaptureProcHeader( d )

	select case lexGetToken( GENTOK_FLAGS )
	case FB_TK_EOL, FB_TK_STMTSEP
		lexSkipToken( GENTOK_FLAGS )
	end select

	if( hCaptureProcBody( d, sym, startline ) = FALSE ) then
		return TRUE
	end if

	if( genopctx.inited = FALSE ) then
		listInit( @genopctx.list, 8, len( FB_GENOP ), LIST_FLAGS_NOCLEAR )
		genopctx.inited = TRUE
		genopctx.head = NULL
		genopctx.tail = NULL
	end if

	dim as FB_GENOP ptr g = listNewNode( @genopctx.list )
	g->gensym = sym
	g->op = op
	g->nxt = NULL

	if( genopctx.tail ) then
		genopctx.tail->nxt = g
	else
		genopctx.head = g
	end if
	genopctx.tail = g

	function = TRUE
end function

'' Flatten a captured chain back into source text.
''
'' Tokens are separated by a single space, which is always safe because they
'' were produced by the lexer in the first place.
''
'' Line structure comes from two sources that must be reconciled, or the replayed
'' text drifts out of step with the source it is blamed on:
''
''   - a real end of line is already in the chain, as a captured EOL token whose
''     text IS the newline, so emitting that token advances the line by itself
''   - a token whose line number is further on than the emitted text has reached
''     means lines were consumed without producing tokens -- a '_' continuation
''     (the lexer hides it) or a multi-line /' '/ comment (skipped, not recorded)
''
'' Padding must therefore track what has actually been emitted, and must NOT
'' close a logical line that the source kept open.  A gap not preceded by an EOL
'' token is a continuation, and is padded with '_' so it stays one statement --
'' padding it with a bare newline is what used to split a parameter list written
'' in the house style across lines, and the error surfaced only at instantiation.
function genFlattenTokens _
	( _
		byval tokhead as FB_GENTOK ptr, _
		byref firstline as integer _
	) as string

	dim as FB_GENTOK ptr n = tokhead
	dim as string res
	dim as integer curline = any
	dim as integer preveol = TRUE

	if( n = NULL ) then
		firstline = 0
		return ""
	end if

	firstline = n->linenum
	curline = n->linenum

	while( n )
		while( curline < n->linenum )
			if( preveol = FALSE ) then
				res += "_"
			end if
			res += LFCHAR
			curline += 1
		wend

		res += *n->text
		res += " "

		'' only an EOL token carries a bare newline as its text
		if( *n->text = LFCHAR ) then
			curline += 1
			preveol = TRUE
		else
			preveol = FALSE
		end if

		n = n->next
	wend

	function = res
end function
