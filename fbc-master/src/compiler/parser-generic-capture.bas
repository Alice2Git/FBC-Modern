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

'' Append one token node to a chain
private function hAddTok _
	( _
		byval gen as FBS_GENERIC ptr, _
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
	n->prev = gen->toktail

	if( gen->toktail ) then
		gen->toktail->next = n
	else
		gen->tokhead = n
	end if
	gen->toktail = n

	function = n
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

'' Flatten a captured chain back into source text.
''
'' Tokens are separated by a single space, which is always safe because they
'' were produced by the lexer in the first place.  Line structure is rebuilt
'' from the recorded line numbers rather than from captured EOL tokens, so a
'' body using '_' line continuations still reports the right lines: the lexer
'' hides the continuation, but the line number still advances across it.
function genFlattenTokens _
	( _
		byval gen as FBS_GENERIC ptr, _
		byref firstline as integer _
	) as string

	dim as FB_GENTOK ptr n = gen->tokhead
	dim as string res
	dim as integer curline = any

	if( n = NULL ) then
		firstline = 0
		return ""
	end if

	firstline = n->linenum
	curline = n->linenum

	while( n )
		while( curline < n->linenum )
			res += LFCHAR
			curline += 1
		wend

		res += *n->text
		res += " "

		n = n->next
	wend

	function = res
end function
