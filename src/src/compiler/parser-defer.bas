'' DEFER statement parsing
''
'' Sketch S.4.  'defer <statement>' runs <statement> on the way out of the
'' enclosing scope, in reverse registration order, on every path.
''
'' The whole implementation is a representation choice: a DEFER is registered as
'' a hidden VAR symbol in the current scope's symbol table, carrying the parsed
'' statement.  Cleanup in fbc is not a list of statements -- it is DERIVED from
'' the scope's symbol table, walked tail-to-head, acting on every entry
'' symbGetVarHasDtor() approves.  So registering a symbol gets reverse order,
'' the correct statement-number window and interleaving with real destructors
'' for free, and the three consumption sites need no knowledge of DEFER at all.
''
'' See symbAddDefer() in symb-var.bas.

#include once "fb.bi"
#include once "fbint.bi"
#include once "parser.bi"
#include once "ast.bi"

'' Is the identifier at the current token a DEFER statement, rather than a use
'' of something the user named 'defer'?
''
'' 'defer' is NOT made a reserved word.  Making it one would break any existing
'' program using it as a name, and the whole point of a contextual keyword is
'' that it costs nothing to programs that do not use the feature.
''
'' One token of look-ahead separates the two readings.  After a statement-initial
'' identifier, everything that continues a USE of that identifier is punctuation:
''
''     defer = 3           assignment to a variable
''     defer(1) = 3        assignment to an array element / a call
''     defer.field = 3     member access
''     defer:              a label definition
''     defer as long       part of a declaration (already consumed by cDeclaration)
''
'' whereas a DEFER statement is always followed by something that BEGINS a
'' statement -- an identifier or a keyword.
''
'' THE ONE AMBIGUITY, stated rather than hidden: a paren-less call in statement
'' position to a sub named 'defer' -- 'defer x' -- now parses as a defer of the
'' statement 'x'.  'defer( x )' still calls it.  This is the same trade FOR EACH
'' already makes, and is covered by a backward-compatibility test.
private function hIsDeferStmt( ) as integer
	select case( lexGetClass( ) )
	case FB_TKCLASS_IDENTIFIER, FB_TKCLASS_QUIRKWD, FB_TKCLASS_KEYWORD
	case else
		return FALSE
	end select

	if( ucase( *lexGetText( ) ) <> "DEFER" ) then
		return FALSE
	end if

	'' a type suffix means it is a variable ('defer$'), never the keyword
	if( lexGetType( ) <> FB_DATATYPE_INVALID ) then
		return FALSE
	end if

	'' a dotted identifier is a member access, never the keyword
	if( lexGetPeriodPos( ) > 0 ) then
		return FALSE
	end if

	'' Tested in the POSITIVE form -- "does the next token BEGIN a statement" --
	'' not as a reject-list of punctuation.  A reject-list gets this wrong:
	'' fbc has no FB_TK_ASSIGN_ADD, so 'defer += 1' lexes as '+' then '=', and
	'' listing only the assignment tokens would have mis-read it as a DEFER of
	'' the statement '+= 1'.  Only an identifier or a keyword can start one.
	select case( lexGetLookAheadClass( 1 ) )
	case FB_TKCLASS_IDENTIFIER, FB_TKCLASS_KEYWORD, FB_TKCLASS_QUIRKWD
		'' 'defer as ...' is never a statement; leave it to whatever follows
		if( lexGetLookAhead( 1 ) = FB_TK_AS ) then
			return FALSE
		end if
		return TRUE

	case else
		'' End of statement: 'defer' with nothing after it.  Claimed anyway so
		'' that it gets its own diagnostic instead of "Variable not declared".
		select case( lexGetLookAhead( 1 ) )
		case FB_TK_EOL, FB_TK_EOF, FB_TK_STMTSEP
			return TRUE
		end select
	end select

	return FALSE
end function



'' DeferStmt  =  DEFER Statement .
''
'' The statement is parsed ONCE, here, into a detached dchain, and cloned at each
'' exit.  Parsing once is what makes the side effects of the deferred statement
'' happen exactly once per exit rather than once per exit PATH, and it reports a
'' syntax error in the deferred statement once rather than once per exit.
function cDeferStmt( ) as integer
	dim as ASTNODE ptr oldcurr = any, oldblock = any, scratch = any, dchain = any
	dim as FBSYMBOL ptr sym = any
	dim as integer res = any

	function = FALSE

	if( hIsDeferStmt( ) = FALSE ) then
		exit function
	end if

	'' Nothing at module level would ever run it: there is no scope to exit.
	if( fbIsModLevel( ) andalso (parser.scope = FB_MAINSCOPE) ) then
		errReport( FB_ERRMSG_DEFERATMODULELEVEL )
		hSkipStmt( )
		return TRUE
	end if

	'' DEFER
	lexSkipToken( )

	select case( lexGetToken( ) )
	case FB_TK_EOL, FB_TK_EOF, FB_TK_STMTSEP
		errReport( FB_ERRMSG_DEFERNEEDSSTATEMENT )
		return TRUE
	end select

	'' Capture into a detached dchain.
	''
	'' astAdd() appends to ast.proc.curr, so pointing that at a throwaway node
	'' for the duration collects the statement -- and any temp destruction it
	'' generates -- instead of emitting it here.  Swapping ast.proc.curr is the
	'' same technique genEnterGlobalScope() uses to build a generic body
	'' somewhere other than where the parser stands.
	scratch = astNewNode( AST_NODECLASS_NOP, FB_DATATYPE_INVALID, NULL )
	scratch->l = NULL
	scratch->r = NULL

	oldcurr = ast.proc.curr
	oldblock = ast.currblock
	ast.proc.curr = scratch
	ast.currblock = scratch

	'' A single statement, and deliberately NOT the full cStatement(): no
	'' declaration (there would be no way to reach what it declared) and no
	'' compound statement (decision: DEFER takes one statement, no block form).
	res = cProcCallOrAssign( )
	if( res = FALSE ) then
		res = cQuirkStmt( )
	end if
	if( res = FALSE ) then
		res = cAssignmentOrPtrCall( )
	end if

	ast.proc.curr = oldcurr
	ast.currblock = oldblock

	dchain = scratch->l
	astDelNode( scratch )

	if( dchain = NULL ) then
		'' the statement parsed to nothing at all -- already diagnosed
		return TRUE
	end if

	'' Detach the captured dchain from any surrounding list.
	dchain->prev = NULL

	sym = symbAddDefer( dchain )
	if( sym = NULL ) then
		errReport( FB_ERRMSG_DEFERNEEDSSTATEMENT )
	end if

	function = TRUE
end function
