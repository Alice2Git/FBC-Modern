''
'' parser protos
''

#include once "lex.bi"
#include once "ast.bi"

'' compound statements permissions
enum FB_CMPSTMT_MASK
	FB_CMPSTMT_MASK_NOTHING     = &h00000000
	FB_CMPSTMT_MASK_CODE        = &h00000001
	FB_CMPSTMT_MASK_PROC        = &h00000002
	FB_CMPSTMT_MASK_NAMESPC     = &h00000004
	FB_CMPSTMT_MASK_DECL        = &h00000008
	FB_CMPSTMT_MASK_EXTERN      = &h00000010
	FB_CMPSTMT_MASK_DATA        = &h00000020
	FB_CMPSTMT_MASK_ALL         = &hFFFFFFFF
	FB_CMPSTMT_MASK_DEFAULT     = FB_CMPSTMT_MASK_CODE
end enum

'' compound statements stats
type FB_CMPSTMTSTK_ as FB_CMPSTMTSTK

type FB_CMPSTMT_DO
	attop           as integer
	inilabel        as FBSYMBOL ptr
	cmplabel        as FBSYMBOL ptr
	endlabel        as FBSYMBOL ptr
	last            as FB_CMPSTMTSTK_ ptr
end type

type FB_CMPSTMT_WHILE
	cmplabel        as FBSYMBOL ptr
	endlabel        as FBSYMBOL ptr
	last            as FB_CMPSTMTSTK_ ptr
end type

type FB_CMPSTMT_FORELM
	sym             as FBSYMBOL ptr             '' if sym = null, value will be used
	value           as FBVALUE
	dtype           as integer
end type

type FB_CMPSTMT_FOR
	outerscopenode  as ASTNODE ptr
	cnt             as FB_CMPSTMT_FORELM
	end             as FB_CMPSTMT_FORELM
	stp             as FB_CMPSTMT_FORELM
	ispos           as FB_CMPSTMT_FORELM
	testlabel       as FBSYMBOL ptr
	inilabel        as FBSYMBOL ptr
	cmplabel        as FBSYMBOL ptr
	endlabel        as FBSYMBOL ptr
	last            as FB_CMPSTMTSTK_ ptr
	explicit_step   as integer

	'' FOR EACH shares this stack entry, and the FB_TK_FOR stack kind, on
	'' purpose: EXIT FOR, CONTINUE FOR and their multi-level forms then count a
	'' FOR EACH as a FOR without knowing it exists, which is what RFC-0003 §8
	'' asks for.
	''
	'' iseach   this is a FOR EACH -- NEXT may not name the variable
	'' eachit   the iterator variable, for a user collection.  NULL for an array
	''          or string, which lower to an ordinary hidden-counter FOR and so
	''          are closed by the existing scalar path with nothing new.
	iseach          as integer
	eachit          as FBSYMBOL ptr
end type

type FB_CMPSTMT_IF
	issingle        as integer
	nxtlabel        as FBSYMBOL ptr
	endlabel        as FBSYMBOL ptr
	elsecnt         as integer
end type

type FB_CMPSTMT_PROC
	tkn             as FB_TOKEN
	is_nested       as integer
	endlabel        as FBSYMBOL ptr
	last            as FB_CMPSTMTSTK_ ptr
end type

type FB_CMPSTMT_SELCONST
	base            as integer
	deflabel        as FBSYMBOL ptr
	dtype           as integer  '' original data type SELECT CASE AS CONST converts sym to u(long)int
	bias            as ulongint '' bias (distance to zero)
end type

type FB_CMPSTMT_SELECT
	isconst         as integer
	sym             as FBSYMBOL ptr
	casecnt         as integer
	const_          as FB_CMPSTMT_SELCONST
	cmplabel        as FBSYMBOL ptr
	endlabel        as FBSYMBOL ptr
	last            as FB_CMPSTMTSTK_ ptr
	outerscopenode      as ASTNODE ptr '' Big scope around the whole SELECT compound (to destroy its temp var)
end type

type FB_CMPSTMT_WITH
	'' The WITH temp var (if it needed to use a pointer), or the variable
	'' (if a simple VAR access was given to the WITH)
	sym         as FBSYMBOL ptr
	is_ptr      as integer
	last        as FB_CMPSTMTSTK_ ptr  '' Previous WITH node on the stack; so parser.stmt.with can be restored in cCompStmtPop()
end type

type FB_CMPSTMT_NAMESPACE
	as FBSYMBOL ptr sym '' Namespace symbol
	as integer levels   '' a.b.c nesting level (multiple nested namespaces in this namespace compound block)
end type

type FB_CMPSTMT_EXTERN
	lastmang        as FB_MANGLING
end type

type FB_CMPSTMT_SCOPE
	lastis_scope    as integer
end type

type FB_CMPSTMTSTK
	id          as integer
	allowmask   as FB_CMPSTMT_MASK
	scopenode   as ASTNODE ptr
	union
		for     as FB_CMPSTMT_FOR
		do      as FB_CMPSTMT_DO
		while   as FB_CMPSTMT_WHILE
		if      as FB_CMPSTMT_IF
		proc    as FB_CMPSTMT_PROC
		select  as FB_CMPSTMT_SELECT
		with    as FB_CMPSTMT_WITH
		nspc    as FB_CMPSTMT_NAMESPACE
		ext     as FB_CMPSTMT_EXTERN
		scp     as FB_CMPSTMT_SCOPE
	end union
end type

type FB_LETSTMT_NODE
	expr            as ASTNODE ptr
end type

type FBPARSER_STMT_LET
	list            as TLIST                    '' of FB_LETSTMT_NODE
end type

'' parser context
type FBPARSER_STMT
	stk             as TSTACK
	id              as FB_TOKEN                 '' current compound stmt id

	cnt             as integer                  '' keep track of :'s to help scope break's

	for             as FB_CMPSTMTSTK ptr
	do              as FB_CMPSTMTSTK ptr
	while           as FB_CMPSTMTSTK ptr
	select          as FB_CMPSTMTSTK ptr
	proc            as FB_CMPSTMTSTK ptr
	with            as FB_CMPSTMTSTK ptr
	let             as FBPARSER_STMT_LET
end type

enum FB_PARSEROPT
	FB_PARSEROPT_NONE             = &h00000000
	FB_PARSEROPT_PRNTOPT          = &h00000001  '' Used to determine if parenthesis are optional and if the next ')' should end the expression for highest precedence operators
	FB_PARSEROPT_CHKARRAY         = &h00000002  '' used by LEN() to handle expr's and ()-less arrays (while set, there will be "array access, index expected" errors, unsetting allows to have no-index arrays, e.g. as bydesc arguments, or in l/ubound())
	FB_PARSEROPT_ISEXPR           = &h00000004  '' parsing an expression?
	FB_PARSEROPT_ISSCOPE          = &h00000008
	FB_PARSEROPT_ISFUNC           = &h00000010
	FB_PARSEROPT_OPTONLY          = &h00000020
	FB_PARSEROPT_HASINSTPTR       = &h00000040
	FB_PARSEROPT_ISPROPGET        = &h00000080
	FB_PARSEROPT_EQINPARENSONLY   = &h00000100  '' only check for '=' if inside parentheses
	FB_PARSEROPT_GTINPARENSONLY   = &h00000200  '' only check for '>' if inside parentheses
	FB_PARSEROPT_ISPP             = &h00000400  '' PP expression? (e.g. #if condition)
	FB_PARSEROPT_EXPLICITBASE     = &h00000800  '' Used to tell cProcArgList() & co about explicit BASE accesses from hBaseMemberAccess() functions
	FB_PARSEROPT_IDXINPARENSONLY  = &h00001000  '' Only parse array index if inside parentheses (used by REDIM, so it can handle 'expr(1 to 2)', where the expression parser should parse 'expr' but not the '(1 to 2)' part)
end enum

type PARSERCTX
	'' stmt recursion
	stmt            as FBPARSER_STMT
	nspcrec         as integer                  '' namespace recursion
	nsprefix        as FBSYMCHAIN ptr           '' used by cTypeOrExpression() & cIdentifier()

	'' globals
	stage           as uinteger                 '' current stage (0=preprocessor, 1=executable)
	scope           as uinteger                 '' current scope (0=main module)

	mangling        as FB_MANGLING              '' current EXTERN's mangling

	currproc        as FBSYMBOL ptr             '' current proc
	currblock       as FBSYMBOL ptr             '' current scope block (= proc if outside any block)

	ovlarglist      as TLIST                    '' used to resolve calls to overloaded functions

	'' hacks
	prntcnt         as integer                  '' ()'s count, to allow optional ()'s on SUB's
	options         as FB_PARSEROPT
	ctx_dtype       as integer                  '' used to resolve the address of overloaded procs
	ctxsym          as FBSYMBOL ptr             '' /
	have_eq_outside_parens  as integer

	'' cProcHeader's pending procedure name.
	''
	'' Here rather than as a function-static because cProcHeader RE-ENTERS
	'' ITSELF: a parameter or return type naming a generic instantiates it on
	'' the spot, and the instantiated type's own member prototypes come back
	'' through this same function.  symbPreAddProc() holds a pointer into this
	'' buffer across that call, and symbAddProc() reads it afterwards, so the
	'' inner declaration used to silently rename the outer one.  Saved and
	'' restored by genSaveState/genRestoreState like the rest of parser state.
	procheaderid    as zstring * FB_MAXNAMELEN+1
end type

'' cSymbolType flags
enum FB_SYMBTYPEOPT
	FB_SYMBTYPEOPT_NONE         = &h00000000

	FB_SYMBTYPEOPT_CHECKSTRPTR  = &h00000001
	FB_SYMBTYPEOPT_ALLOWFORWARD = &h00000002
	FB_SYMBTYPEOPT_ISBYREF      = &h00000004
	FB_SYMBTYPEOPT_SAVENSPREFIX = &h00000008    '' used by cTypeOrExpression() & cIdentifier()

	FB_SYMBTYPEOPT_DEFAULT      = FB_SYMBTYPEOPT_CHECKSTRPTR
end enum

'' cIdentifier flags
enum FB_IDOPT
	FB_IDOPT_NONE               = &h00000000

	FB_IDOPT_DONTCHKPERIOD      = &h00000001
	FB_IDOPT_SHOWERROR          = &h00000002
	FB_IDOPT_ISDECL             = &h00000004
	FB_IDOPT_ALLOWOPERATOR      = &h00000008  '' allow operators in identifier
	FB_IDOPT_ALLOWSTRUCT        = &h00000010
	FB_IDOPT_CHECKSTATIC        = &h00000020
	FB_IDOPT_ISVAR              = &h00000040  '' parsing namespace prefix for variable declaration?
	FB_IDOPT_NOSKIP             = &h00000080  '' don't skip unused token, caller will do it
	FB_IDOPT_ISDEFN             = &h00000100  '' is definition (i,e, procedure definition), ignore some access checks
	FB_IDOPT_ALLOWMEMBERS       = &h00000200  '' allow operators / constructors / destructors in identifier

	FB_IDOPT_DEFAULT            = FB_IDOPT_SHOWERROR or FB_IDOPT_CHECKSTATIC
end enum

'' cInitializer flags
enum FB_INIOPT
	FB_INIOPT_NONE              = &h00000000  '' expression
	FB_INIOPT_ISINI             = &h00000001  '' initializer (not an expression)
	FB_INIOPT_ISOBJ             = &h00000002  '' object with constructor
	FB_INIOPT_NOUPCAST          = &h00000004  '' don't allow upcasting (base types initialized from derived types)
end enum

'' cProcHeader() flags
enum FB_PROCOPT
	FB_PROCOPT_NONE         = &h00000000
	FB_PROCOPT_ISPROTO      = &h00000001
	FB_PROCOPT_HASPARENT    = &h00000002
end enum

'' cVarOrDeref flags
enum FB_VAREXPROPT
	FB_VAREXPROPT_NONE            = &h00000000
	FB_VAREXPROPT_NOARRAYCHECK    = &h00000001
	FB_VAREXPROPT_ALLOWALLCASTS   = &h00000002
	FB_VAREXPROPT_ISEXPR          = &h00000004
	FB_VAREXPROPT_ISASSIGN        = &h00000010  '' Used by SWAP to disallow CALLs etc.
end enum

declare sub parserAsmInit( )
declare sub parserAsmEnd( )

declare function parserInlineAsmAddKeyword( byval id as const zstring ptr ) as integer

declare function parserGlobalAsmAddKeyword( byval id as const zstring ptr ) as integer
declare function parserIsGlobalAsmKeyword( byval id as const zstring ptr ) as integer

declare sub cProgram()

declare function cLabel _
	( _
		_
	) as integer

declare function cComment _
	( _
		byval lexflags as LEXCHECK = LEXCHECK_EVERYTHING _
	) as integer

declare sub cStatement()

declare function cStmtSeparator _
	( _
		byval lexflags as LEXCHECK = LEXCHECK_EVERYTHING _
	) as integer

declare function cDeclaration _
	( _
		_
	) as integer

declare sub cConstDecl( byval attrib as FB_SYMBATTRIB )
declare sub cTypeDecl( byval attrib as FB_SYMBATTRIB )
declare sub cTypedefMultDecl( byval attrib as FB_SYMBATTRIB )
declare sub cTypedefSingleDecl( byval attrib as FB_SYMBATTRIB, byval pid as zstring ptr )
declare sub cEnumDecl( byval attrib as FB_SYMBATTRIB )
declare function hCheckScope() as integer

declare function cVariableDecl _
	( _
		byval attrib as FB_SYMBATTRIB = FB_SYMBATTRIB_NONE _
	) as integer

declare sub cArrayDecl _
	( _
		byref dimensions as integer, _
		byref have_bounds as integer, _
		exprTB() as ASTNODE ptr _
	)

declare function cInitializer _
	( _
		byval sym as FBSYMBOL ptr, _
		byval options as FB_INIOPT, _
		byval dtype as integer = FB_DATATYPE_INVALID, _
		byval subtype as FBSYMBOL ptr = NULL _
	) as ASTNODE ptr

declare function cTypeOrExpression _
	( _
		byval tk as integer, _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as longint = 0, _
		byref is_fixlenstr as integer = FALSE _
	) as ASTNODE ptr

declare sub cTypeOf _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as longint, _
		byref is_fixlenstr as integer, _
		byref ret_sym as FBSYMBOL ptr = NULL _
	)

declare function cSymbolType _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as longint = 0, _
		byref is_fixlenstr as integer = FALSE, _
		byval options as FB_SYMBTYPEOPT = FB_SYMBTYPEOPT_DEFAULT _
	) as integer

declare function cIdentifier _
	( _
		byref base_parent as FBSYMBOL ptr, _
		byval options as FB_IDOPT = FB_IDOPT_DEFAULT _
	) as FBSYMCHAIN ptr

declare function cParentId _
	( _
		byval options as FB_IDOPT = FB_IDOPT_NONE _
	) as FBSYMBOL ptr

declare sub cCurrentParentId( )

declare function cIdentifierOrUDTMember _
	( _
		byref parent as FBSYMBOL ptr = NULL, _
		byval chain_ as FBSYMCHAIN ptr = NULL _
	) as FBSYMBOL ptr

declare sub cProcDecl( )

declare function cProcHeader _
	( _
		byval attrib as FB_SYMBATTRIB, _
		byval pattrib as FB_PROCATTRIB, _
		byref is_nested as integer, _
		byval options as FB_PROCOPT, _
		byval tk as integer _
	) as FBSYMBOL ptr

declare sub cParameters _
	( _
		byval parent as FBSYMBOL ptr, _
		byval proc as FBSYMBOL ptr, _
		byval procmode as integer, _
		byval isproto as integer _
	)

declare sub cDefDecl( )
declare sub cOptDecl( )

declare function cProcCallOrAssign _
	( _
		_
	) as integer

declare function cQuirkStmt _
	( _
		byval tk as FB_TOKEN = INVALID _
	) as integer

declare function cCompoundStmt _
	( _
		_
	) as integer

declare function cCompStmtCheck _
	( _
		_
	) as integer

declare function cCompStmtPush _
	( _
		byval id as FB_TOKEN, _
		byval allowmask as FB_CMPSTMT_MASK = FB_CMPSTMT_MASK_DEFAULT _
	) as FB_CMPSTMTSTK ptr

declare function cCompStmtGetTOS _
	( _
		byval forid as FB_TOKEN, _
		byval showerror as integer = TRUE _
	) as FB_CMPSTMTSTK ptr

declare sub cCompStmtPop( byval stk as FB_CMPSTMTSTK ptr )

declare function cCompStmtIsAllowed _
	( _
		byval allowmask as FB_CMPSTMT_MASK _
	) as integer

declare sub cIfStmtBegin( )
declare sub cIfStmtNext( )
declare sub cIfStmtEnd( )
declare sub cForStmtBegin( )

'' FOR EACH -- RFC-0003.  cForIsEach() is the one token of look-ahead that tells
'' 'for each n in c' from the still-legal 'for each as long = 1 to 3'.
declare function cForIsEach( ) as integer
declare sub cForEachStmtBegin( )

'' Declare a local initialised from an already-parsed expression (see the body
'' in parser-decl-var.bas).
declare function cDeclLocalFromExpr _
	( _
		byval id as zstring ptr, _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval isref as integer, _
		byval expr as ASTNODE ptr _
	) as FBSYMBOL ptr
declare sub cForStmtEnd( )
declare sub cDoStmtBegin( )
declare sub cDoStmtEnd( )
declare sub cWhileStmtBegin( )
declare sub cWhileStmtEnd( )
declare sub cSelectStmtBegin( )
declare sub cSelectStmtNext( )
declare sub cSelectStmtEnd( )
declare sub cSelConstStmtBegin( )
declare sub cSelConstStmtNext( byval stk as FB_CMPSTMTSTK ptr )
declare sub cSelConstStmtEnd( byval stk as FB_CMPSTMTSTK ptr )
declare sub hDisallowStaticAttrib( byref attrib as FB_SYMBATTRIB, byref pattrib as FB_PROCATTRIB )
declare sub hDisallowVirtualCtor( byref attrib as FB_SYMBATTRIB, byref pattrib as FB_PROCATTRIB )
declare sub hDisallowAbstractDtor( byref attrib as FB_SYMBATTRIB, byref pattrib as FB_PROCATTRIB )
declare sub hDisallowConstCtorDtor( byval tk as integer, byref attrib as FB_SYMBATTRIB, byref pattrib as FB_PROCATTRIB )
declare sub cProcStmtBegin( byval attrib as FB_SYMBATTRIB = 0, byval pattrib as FB_PROCATTRIB = 0 )
declare sub cProcStmtEnd( )
declare sub cExitStatement( )
declare sub cEndStatement( )
declare sub cContinueStatement( )
declare sub cWithStmtBegin( )
declare sub cWithStmtEnd( )
declare sub cScopeStmtBegin( )
declare sub cScopeStmtEnd( )

declare sub cNamespaceStmtBegin( )
declare sub cNamespaceStmtEnd( )
declare sub cUsingStmt( )
declare sub cExternStmtBegin( )
declare sub cExternStmtEnd( )

declare function cDeferStmt( ) as integer

declare function cAssignmentOrPtrCall _
	( _
		_
	) as integer

declare function cAssignmentOrPtrCallEx _
	( _
		byval expr as ASTNODE ptr _
	) as integer

declare function hIsAssignToken( byval token as integer ) as integer
declare function cAssignToken( ) as integer

declare function cOperator( byval is_overload as integer ) as integer

declare function cExpression _
	( _
		_
	) as ASTNODE ptr

declare function cExpressionWithNIDXARRAY( byval allow_nidxarray as integer ) as ASTNODE ptr

declare function cCatExpression _
	( _
		_
	) as ASTNODE ptr

declare function cBoolExpression _
	( _
		_
	) as ASTNODE ptr

declare function cLogExpression _
	( _
		_
	) as ASTNODE ptr

declare function cRelExpression _
	( _
		_
	) as ASTNODE ptr

declare function cAddExpression _
	( _
		_
	) as ASTNODE ptr

declare function cShiftExpression _
	( _
		_
	) as ASTNODE ptr

declare function cModExpression _
	( _
		_
	) as ASTNODE ptr

declare function cIntDivExpression _
	( _
		_
	) as ASTNODE ptr

declare function cMultExpression _
	( _
		_
	) as ASTNODE ptr

declare function cExpExpression _
	( _
		_
	) as ASTNODE ptr

declare function cNegNotExpression _
	( _
		_
	) as ASTNODE ptr

declare function cHighestPrecExpr _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval chain_ as FBSYMCHAIN ptr _
	) as ASTNODE ptr

declare function cDerefExpression( ) as ASTNODE ptr

declare function cProcPtrBody _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	) as ASTNODE ptr

declare function cAddrOfExpression( ) as ASTNODE ptr

declare function cTypeConvExpr _
	( _
		byval tk as FB_TOKEN, _
		byval isASM as integer = FALSE _
	) as ASTNODE ptr

declare function cEqInParensOnlyExpr _
	( _
		_
	) as ASTNODE ptr

declare function cGtInParensOnlyExpr _
	( _
		_
	) as ASTNODE ptr

declare function cParentExpression _
	( _
		_
	) as ASTNODE ptr

declare function cAtom _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval chain_ as FBSYMCHAIN ptr _
	) as ASTNODE ptr

declare function cVariable _
	( _
		byval chain as FBSYMCHAIN ptr, _
		byval checkarray as integer = TRUE _
	) as ASTNODE ptr

declare function cVariableEx overload _
	( _
		byval sym as FBSYMBOL ptr, _
		byval check_array as integer _
	) as ASTNODE ptr

declare function cVariableEx _
	( _
		byval chain as FBSYMCHAIN ptr, _
		byval checkarray as integer _
	) as ASTNODE ptr

declare function cWithVariable( byval checkarray as integer ) as ASTNODE ptr

declare function cImplicitDataMember _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval chain_ as FBSYMCHAIN ptr, _
		byval checkarray as integer, _
		byval options as FB_PARSEROPT _
	) as ASTNODE ptr

declare function cVarOrDeref _
	( _
		byval options as FB_VAREXPROPT = FB_VAREXPROPT_NONE _
	) as ASTNODE ptr

declare function cFunctionEx _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval sym as FBSYMBOL ptr, _
		byval options as FB_PARSEROPT = 0 _
	) as ASTNODE ptr

declare function cQuirkFunction _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

declare function cConstant( byval sym as FBSYMBOL ptr ) as ASTNODE ptr

declare function cEnumConstant _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

declare function cStrLiteral( byval skiptoken as integer = TRUE ) as ASTNODE ptr
declare function cNumLiteral( byval skiptoken as integer = TRUE ) as ASTNODE ptr

declare function cProcArgList _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval proc as FBSYMBOL ptr, _
		byval ptrexpr as ASTNODE ptr, _
		byval arg_list as FB_CALL_ARG_LIST ptr, _
		byval options as FB_PARSEROPT _
	) as ASTNODE ptr

declare function cAsmBlock _
	( _
		_
	) as integer

declare function cAliasAttribute( ) as zstring ptr
declare sub cLibAttribute( )
declare sub cMethodAttributes _
	( _
		byval parent as FBSYMBOL ptr, _
		byref attrib as FB_SYMBATTRIB, _
		byref pattrib as FB_PROCATTRIB _
	)

declare sub cProcRetType _
	( _
		byval attrib as FB_SYMBATTRIB, _
		byval pattrib as FB_PROCATTRIB, _
		byval proc as FBSYMBOL ptr, _
		byval is_proto as integer, _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr _
	)

declare function cProcReturnMethod _
	( _
		byval dtype as FB_DATATYPE _
	) as FB_PROC_RETURN_METHOD

declare function cProcCallingConv _
	( _
		byval default as FB_FUNCMODE = FB_FUNCMODE_FBCALL, _
		byref is_explicit as integer = FALSE _
	) as FB_FUNCMODE

declare sub cByrefAttribute( byref pattrib as FB_PROCATTRIB, byval is_func as integer )

declare function cFunctionCall _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval sym as FBSYMBOL ptr, _
		byval ptrexpr as ASTNODE ptr, _
		byval thisexpr as ASTNODE ptr = NULL, _
		byval options as FB_PARSEROPT = 0 _
	) as ASTNODE ptr

declare sub hMethodCallAddInstPtrOvlArg _
	( _
		byval proc as FBSYMBOL ptr, _
		byval thisexpr as ASTNODE ptr, _
		byval arg_list as FB_CALL_ARG_LIST ptr, _
		byval options as FB_PARSEROPT ptr _
	)

declare function cMaybeIgnoreCallResult( byval expr as ASTNODE ptr ) as integer

declare function cProcCall _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval sym as FBSYMBOL ptr, _
		byval ptrexpr as ASTNODE ptr, _
		byval thisexpr as ASTNODE ptr = NULL, _
		byval checkprnts as integer = FALSE, _
		byval options as FB_PARSEROPT = 0 _
	) as ASTNODE ptr

declare function cMethodCall _
	( _
		byval sym as FBSYMBOL ptr, _
		byval thisexpr as ASTNODE ptr, _
		byval options as FB_PARSEROPT _
	) as ASTNODE ptr

declare function cCtorCall _
	( _
		byval sym as FBSYMBOL ptr _
	) as ASTNODE ptr

declare function cUdtMember _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval varexpr as ASTNODE ptr, _
		byval check_array as integer, _
		byval options as FB_PARSEROPT = 0 _
	) as ASTNODE ptr

declare sub cUdtTypeMember _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as longint, _
		byref is_fixlenstr as integer, _
		byref ret_sym as FBSYMBOL ptr = NULL _
	)

declare function cMemberAccess _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

declare function cMemberDeref _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval varexpr as ASTNODE ptr, _
		byval checkarray as integer _
	) as ASTNODE ptr

declare function cFuncPtrOrMemberDeref _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr, _
		byval varexpr as ASTNODE ptr, _
		byval isfuncptr as integer, _
		byval checkarray as integer _
	) as ASTNODE ptr

declare function cStrIdxOrMemberDeref _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

declare sub cAssignment(byval assgexpr as ASTNODE ptr)
declare function cAssignFunctResult( byval is_return as integer ) as integer

declare function cGfxStmt _
	( _
		byval tk as FB_TOKEN _
	) as integer

declare function cGfxFunct _
	( _
		byval tk as FB_TOKEN _
	) as ASTNODE ptr

declare function cGotoStmt _
	( _
		byval tk as FB_TOKEN _
	) as integer

declare function cPrintStmt _
	( _
		byval tk as FB_TOKEN _
	) as integer

declare function cDataStmt _
	( _
		byval tk as FB_TOKEN _
	) as integer

declare function cEraseStmt() as integer
declare function cSwapStmt() as integer

declare function cLineInputStmt _
	( _
		_
	) as integer

declare function cInputStmt _
	( _
		_
	) as integer

declare function cPokeStmt _
	( _
		_
	) as integer

declare function cFileStmt _
	( _
		byval tk as FB_TOKEN _
	) as integer

declare function cOnStmt _
	( _
		_
	) as integer

declare function cWriteStmt() as integer
declare function cErrorStmt() as integer
declare function cErrSetStmt() as integer
declare function cViewStmt(byval is_func as integer) as ASTNODE ptr
declare function cMidStmt( ) as integer
declare function cLRSetStmt(byval tk as FB_TOKEN) as integer
declare function cWidthStmt(byval isfunc as integer) as ASTNODE ptr
declare function cColorStmt(byval isfunc as integer) as ASTNODE ptr
declare function cStringFunct(byval tk as FB_TOKEN) as ASTNODE ptr
declare function cCVXFunct(byval tk as FB_TOKEN) as ASTNODE ptr
declare function cMKXFunct(byval tk as FB_TOKEN) as ASTNODE ptr
declare function cMathFunct _
	( _
		byval tk as FB_TOKEN, _
		byval isasm as integer _
	) as ASTNODE ptr
declare function cPeekFunct() as ASTNODE ptr
declare function cArrayFunct(byval tk as FB_TOKEN) as ASTNODE ptr
declare function cFileFunct(byval tk as FB_TOKEN) as ASTNODE ptr
declare function cErrorFunct() as ASTNODE ptr
declare function cIIFFunct() as ASTNODE ptr
declare function cVAFunct() as ASTNODE ptr
declare function cVALISTFunct( byval tk as FB_TOKEN ) as ASTNODE ptr
declare function cVALISTStmt( byval tk as FB_TOKEN ) as integer
declare function cScreenFunct() as ASTNODE ptr
declare function cAnonType( ) as ASTNODE ptr
declare function cConstIntExpr _
	( _
		byval expr as ASTNODE ptr, _
		byval dtype as integer = FB_DATATYPE_INTEGER _
	) as longint
declare function hIsConstInRange _
	( _
		byval dtype as integer, _
		byval value as longint, _
		byval todtype as integer _
	) as integer
declare function cConstIntExprRanged _
	( _
		byval expr as ASTNODE ptr, _
		byval dtype as integer = FB_DATATYPE_INTEGER _
	) as longint
declare function cOperatorNew( ) as ASTNODE ptr
declare sub cOperatorDelete( )

declare sub hSkipUntil _
	( _
		byval token as integer, _
		byval doeat as integer = FALSE, _
		byval flags as LEXCHECK = LEXCHECK_EVERYTHING, _
		byval stop_on_comma as integer = FALSE _
	)

declare sub hSkipCompound _
	( _
		byval for_token as integer, _
		byval until_token as integer = INVALID, _
		byval flags as LEXCHECK = LEXCHECK_EVERYTHING _
	)

declare function hMatchExpr _
	( _
		byval dtype as integer _
	) as ASTNODE ptr

declare sub hMaybeConvertExprTb2DimTb _
	( _
		byref attrib as FB_SYMBATTRIB, _
		byval dimensions as integer, _
		exprTB() as ASTNODE ptr, _
		dTB() as FBARRAYDIM _
	)

declare sub hComplainAboutEllipsis _
	( _
		byval dimensions as integer, _
		exprTB() as ASTNODE ptr, _
		byval errmsg as integer _
	)

declare function cVarDecl _
	( _
		byval attrib as FB_SYMBATTRIB, _
		byval dopreserve as integer, _
		byval token as integer, _
		byval is_fordecl as integer _
	) as FBSYMBOL ptr

declare sub hComplainIfAbstractClass _
	( _
		byval dtype as integer, _
		byval subtype as FBSYMBOL ptr _
	)

declare sub hComplainAboutConstDynamicArray( byval sym as FBSYMBOL ptr )

declare sub hSymbolType _
	( _
		byref dtype as integer, _
		byref subtype as FBSYMBOL ptr, _
		byref lgt as longint, _
		byval is_byref as integer = FALSE, _
		byval is_extends as integer = FALSE _
	)

declare function hCheckForDefiniteTypes _
	( _
		_
	) as integer

declare function hCheckForDefiniteExprs _
	( _
		_
	) as integer

declare function cThreadCallFunc() as ASTNODE ptr

declare function hIntegerTypeFromBitSize _
	( _
		byval bitsize as longint, _
		byval is_unsigned as integer = FALSE _
	) as FB_DATATYPE

''
'' macros
''
#define cCompSetAllowmask(s, v) s->allowmask = v

#define hSkipStmt( ) _
	hSkipUntil( INVALID, FALSE )

'':::::
#macro hMatchLPRNT()
	if( lexGetToken( ) <> CHAR_LPRNT ) then
		errReport( FB_ERRMSG_EXPECTEDLPRNT )
	else
		lexSkipToken( )
	end if
#endmacro

'':::::
#macro hMatchRPRNT()
	if( lexGetToken( ) <> CHAR_RPRNT ) then
		errReport( FB_ERRMSG_EXPECTEDRPRNT )
		hSkipUntil( CHAR_RPRNT, TRUE )
	else
		lexSkipToken( )
	end if
#endmacro

'':::::
#macro hMatchCOMMA()
	if( lexGetToken( ) <> CHAR_COMMA ) then
		errReport( FB_ERRMSG_EXPECTEDCOMMA )
	else
		lexSkipToken( )
	end if
#endmacro

'':::::
#macro hMatchExpression(e)
	e = hMatchExpr( INVALID )
	if( e = NULL ) then
		exit function
	end if
#endmacro

'':::::
#macro hMatchExpressionEx(e, dtype)
	e = hMatchExpr( dtype )
	if( e = NULL ) then
		exit function
	end if
#endmacro

'':::::
#macro hMatchFileNumberExpression(e, dtype)
	e = cExpression( )
	if( e = NULL ) then
		errReport( FB_ERRMSG_EXPECTEDFILENUMBEREXPRESSION )
		'' error recovery: fake an expr
		if( dtype = FB_DATATYPE_INVALID ) then
			return NULL
		end if

		e = astNewCONSTz( dtype )
	end if
#endmacro

'':::::
#macro hEmitCurrLine( )
	if( env.clopt.debuginfo ) then
		if( env.includerec = 0 ) then
			astAdd( astNewLIT( lexCurrLineGet( ) ) )
			lexCurrLineReset( )
		end if
	end if
#endmacro

#define hGetInstPtrMode(ip) iif( astIsCONST( ip ), FB_PARAMMODE_BYVAL, INVALID )

#define fbIsModLevel( ) (parser.currproc = env.main.proc)

#define fbGetCompStmtId( ) parser.stmt.id

#define fbGetPrntOptional( ) ((parser.options and FB_PARSEROPT_PRNTOPT) <> 0)

#macro fbSetPrntOptional( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_PRNTOPT
	else
		parser.options and= not FB_PARSEROPT_PRNTOPT
	end if
#endmacro

#define fbGetCheckArray( ) ((parser.options and FB_PARSEROPT_CHKARRAY) <> 0)

#macro fbSetCheckArray( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_CHKARRAY
	else
		parser.options and= not FB_PARSEROPT_CHKARRAY
	end if
#endmacro

#define fbGetIsExpression( ) ((parser.options and FB_PARSEROPT_ISEXPR) <> 0)

#macro fbSetIsExpression( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_ISEXPR
	else
		parser.options and= not FB_PARSEROPT_ISEXPR
	end if
#endmacro

#define fbGetIsScope( ) ((parser.options and FB_PARSEROPT_ISSCOPE) <> 0)

#macro fbSetIsScope( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_ISSCOPE
	else
		parser.options and= not FB_PARSEROPT_ISSCOPE
	end if
#endmacro

#define fbGetEqInParensOnly( ) ((parser.options and FB_PARSEROPT_EQINPARENSONLY) <> 0)

#macro fbSetEqInParensOnly( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_EQINPARENSONLY
	else
		parser.options and= not FB_PARSEROPT_EQINPARENSONLY
	end if
#endmacro

#define fbGetGtInParensOnly( ) ((parser.options and FB_PARSEROPT_GTINPARENSONLY) <> 0)

#macro fbSetGtInParensOnly( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_GTINPARENSONLY
	else
		parser.options and= not FB_PARSEROPT_GTINPARENSONLY
	end if
#endmacro

'' Whether the expression being parsed is a PP expression (#ifdef etc.)
#define fbGetIsPP( ) ((parser.options and FB_PARSEROPT_ISPP) <> 0)
#macro fbSetIsPP( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_ISPP
	else
		parser.options and= not FB_PARSEROPT_ISPP
	end if
#endmacro

#define fbGetIdxInParensOnly( ) ((parser.options and FB_PARSEROPT_IDXINPARENSONLY) <> 0)
#macro fbSetIdxInParensOnly( _bool )
	if( _bool ) then
		parser.options or= FB_PARSEROPT_IDXINPARENSONLY
	else
		parser.options and= not FB_PARSEROPT_IDXINPARENSONLY
	end if
#endmacro

''
'' generics -- body capture (parser-generic-capture.bas)
''

declare sub genCaptureEnd( )
declare sub genInstCacheEnd( )

declare function cGenericTypeArgs( byval gensym as FBSYMBOL ptr ) as FBSYMBOL ptr

declare function genInstantiateType _
	( _
		byval gensym as FBSYMBOL ptr, _
		argdtype() as integer, _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	) as FBSYMBOL ptr

declare sub cGenericTypeDecl _
	( _
		byval attrib as FB_SYMBATTRIB, _
		byval id as const zstring ptr, _
		byval isunion as integer _
	)

declare function genCaptureTypeBody _
	( _
		byval sym as FBSYMBOL ptr, _
		byval startline as integer _
	) as integer

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
	stmtcnt         as integer
	stmttos         as any ptr                  '' compound-stmt stack top, for the balance assert

	'' cProcHeader's pending procedure name.
	''
	'' A replay is triggered from the MIDDLE of cProcHeader whenever a parameter
	'' or return type names a generic, and the instantiated type's own member
	'' prototypes run through cProcHeader again.  Without this,
	''     declare function GetIterator( ) as ArrayIterator( of T )
	'' was added under the name of ArrayIterator's LAST member, and GetIterator
	'' itself never existed -- the body then failed with 'error 158: Declaration
	'' outside the original namespace or class'.
	procheaderid    as zstring * FB_MAXNAMELEN+1

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

type FB_GENSCOPE
	scope           as uinteger
	currproc        as FBSYMBOL ptr
	currblock       as FBSYMBOL ptr
	astproc         as ASTNODE ptr
	astblock        as ASTNODE ptr
	symtb           as FBSYMBOLTB ptr
	hashtb          as FBHASHTB ptr
	ns              as FBSYMBOL ptr
	declns          as FBSYMBOL ptr             '' generic's declaring ns, or NULL
	hidelocals       as integer                  '' did this entry bump symb.hidelocals?
end type

declare sub genEnterGlobalScope _
	( _
		byref gs as FB_GENSCOPE, _
		byval gensym as FBSYMBOL ptr, _
		byval hidelocals as integer _
	)

declare sub genLeaveGlobalScope( byref gs as FB_GENSCOPE )

declare function genCurrentInstNamespc( ) as FBSYMBOL ptr

declare function lambdaOpensHere _
	( _
		byval prevtk as integer, _
		byval prevprevtk as integer, _
		byval flags as integer _
	) as integer

declare function genReplayBegin _
	( _
		byref st as FB_PARSERSTATE, _
		byref text as string, _
		byval linenum as integer, _
		byval srcfile as zstring ptr _
	) as integer

declare sub genReplayEnd( byref st as FB_PARSERSTATE )

'' The name of a closure struct's call operator. Shared so the call site in
'' parser-expr-unary.bas can find it.
#define FB_INVOKE_NAME "__FBINVOKE"

declare function cLambdaExpr( ) as ASTNODE ptr
declare function genInstDesc _
	( _
		byval inst as FBSYMBOL ptr, _
		byref gensym as FBSYMBOL ptr _
	) as zstring ptr
declare sub lambdaDrainBodies( )
declare function lambdaInHeaderReplay( ) as integer

declare function genFlattenTokens _
	( _
		byval tokhead as FB_GENTOK ptr, _
		byref firstline as integer _
	) as string

'' One out-of-line member body belonging to a generic, e.g.
''     sub Stack( of T ).Push( byval x as T ) ... end sub
'' The captured chain starts at the '.' (or at the '(' for a ctor), so replaying
'' it only needs the kind keyword and the instantiated struct's internal name
'' pasted in front.
type FB_GENPROC
	gensym          as FBSYMBOL ptr
	kindtk          as integer                  '' FB_TK_SUB / FUNCTION / OPERATOR / ...

	'' A generic PROCEDURE's own signature: '( params ) [as ret]'.  NULL for a
	'' member body of a generic type, whose captured chain already starts with
	'' '.name( params )' and so needs no separate header.
	''
	'' The two are kept apart because they are replayed at different times: this
	'' half is replayed EAGERLY, the moment a call site needs a callable symbol,
	'' as 'declare sub __FBGENPROC( ... )'; the body waits for a statement
	'' boundary like any other, since a call site is mid-expression and no
	'' procedure can be opened there.
	hdrhead         as FB_GENTOK ptr
	hdrtail         as FB_GENTOK ptr

	'' AST_OP of a generic GLOBAL operator, or INVALID for everything else.
	'' A global operator has no name to replay, so its captured header chain
	'' starts with the operator's own token instead and the replay pastes only
	'' the kind keyword in front -- 'operator' + '+ ( ... ) as ...' -- where a
	'' named generic procedure gets 'function' + '__FBGENPROC' + '( ... )'.
	op              as integer

	tokhead         as FB_GENTOK ptr            '' body, through 'end sub'
	toktail         as FB_GENTOK ptr
	srcline         as integer
	srcfile         as zstring ptr
	nxt             as FB_GENPROC ptr           '' next body of the SAME generic, in source order
end type

declare function genGenericName( byval gensym as FBSYMBOL ptr ) as zstring ptr
declare function genLookupGeneric( ) as FBSYMBOL ptr
declare function genIsGenericMemberProc( ) as integer
declare function genIsGenericProcDecl( ) as integer
declare function cGenericProcDeclNew( byval tk as integer ) as integer

'' One generic GLOBAL operator declaration.  Kept in a list of its own rather
'' than in the symbol hash: a global operator has no name to be looked up by,
'' and resolution starts from the AST_OP and the operand types.
type FB_GENOP
	gensym          as FBSYMBOL ptr
	op              as integer
	nxt             as FB_GENOP ptr
end type

'' Is the parser looking at 'operator <op>( of T )( ... )'?  The kind keyword has
'' already been consumed and the current token is the operator itself.
declare function genIsGenericOpDecl( ) as integer
declare function cGenericOpDecl( byval tk as integer ) as integer
declare function genGetGenericOps( ) as FB_GENOP ptr

'' Called from hTypeAdd right after symbStructBegin: if a generic body is being
'' replayed, this is the instantiated struct, and it needs its ALIAS and
'' GENERICINST flag now rather than after its body is parsed.
declare sub genTagInstantiation( byval sym as FBSYMBOL ptr )

'' Instantiate whatever generic global operators can be inferred from these
'' operand types, so ordinary overload resolution finds them a moment later.
'' Silent: an operand that matches nothing is not an error here, it simply means
'' this operator was never generic.  Pass rdtype = FB_DATATYPE_INVALID for a
'' unary operator.
declare sub genTryInstantiateGlobalOp _
	( _
		byval op as integer, _
		byval ldtype as integer, _
		byval lsubtype as FBSYMBOL ptr, _
		byval rdtype as integer, _
		byval rsubtype as FBSYMBOL ptr _
	)

'' Resolve 'Name( of long )' at a call site to the instantiated procedure.
'' On entry the identifier has already been consumed and the current token is
'' the '(' of the type-argument list.  Returns NULL on error.
declare function cGenericProcArgs( byval gensym as FBSYMBOL ptr ) as FBSYMBOL ptr

'' An inferred call, with no type arguments written: 'Swap2( x, y )'.
'' On entry the identifier has been consumed and the current token is the '(' of
'' the ordinary argument list.
declare function cGenericProcInferredCall _
	( _
		byval base_parent as FBSYMBOL ptr, _
		byval gensym as FBSYMBOL ptr, _
		byval options as FB_PARSEROPT _
	) as ASTNODE ptr

'' Is the token after the consumed generic name an explicit '( of ...' list?
declare function genHasExplicitTypeArgs( ) as integer

'' The same, asked before the name is consumed.
declare function genHasExplicitTypeArgsAfterId( ) as integer

declare function genInstantiateProc _
	( _
		byval gensym as FBSYMBOL ptr, _
		argdtype() as integer, _
		argsubtype() as FBSYMBOL ptr, _
		byval argcount as integer _
	) as FBSYMBOL ptr
declare function cGenericProcDecl( byval tk as integer ) as integer
declare function genGetProcBodies( byval gensym as FBSYMBOL ptr ) as FB_GENPROC ptr
declare sub genQueueProcBodies _
	( _
		byval gensym as FBSYMBOL ptr, _
		byval nsp as FBSYMBOL ptr, _
		byval body as FB_GENPROC ptr _
	)
declare sub genDrainProcBodies( )
declare sub genProcBodyEnd( )

''
'' inter-module globals
''
extern parser as PARSERCTX
