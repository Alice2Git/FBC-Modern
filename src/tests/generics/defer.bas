' TEST_MODE : COMPILE_AND_RUN_OK

'' DEFER -- registration, the fallthrough exits, and every break path.
''
'' Covered here: reverse order, fallthrough off 'end scope' and off
'' 'end sub'/'end function', a defer in a loop body, interleaving with real
'' destructors in both orders, reading a local declared before the defer, defers
'' inside IF/SELECT/WITH arms, and backward compatibility for code that uses
'' 'defer' as an identifier.
''
'' Phase 4 adds the BREAK paths -- 'exit sub', 'exit function', 'return',
'' 'exit for/while/do' including the multi-level forms, and 'goto' out of one
'' and out of three nested scopes. Those go through astScopeBreak( ) and
'' hDestroyBlockLocals( ) rather than astScopeDestroyVars( ), so they are
'' asserted separately below even where the expected sequence looks the same.
''
'' ORDER IS ASSERTED BY ACCUMULATING INTO A STRING and comparing the exact
'' sequence, never by eyeballing output: a defer that runs at the wrong time
'' still runs, so only the sequence distinguishes right from wrong.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as string log_

'' A type whose destructor logs, so defers and real destructors can be shown to
'' interleave in one order rather than running in two separate passes.
type Tr
	as string nm
	declare destructor( )
end type

destructor Tr( )
	log_ &= "~" & this.nm
end destructor

'' Backward-compatibility fixtures. A TYPE and a 'dim shared' cannot be
'' forward-referenced, so they live here rather than with the procedures below.
type HasDeferField
	as long defer
end type

dim shared as long deferShared

declare sub scopeFallthrough( )
declare sub procFallthrough( )
declare function funcFallthrough( ) as long
declare sub interleaveDeferFirst( )
declare sub interleaveVarFirst( )
declare sub loopBody( )
declare sub readsLocal( )
declare sub nestedScopes( )
declare sub inIfArm( byval n as long )
declare sub inSelectArm( byval n as long )
declare sub inWithBlock( )
declare sub manyDefers( )
declare sub exitSub( byval n as long )
declare function exitFunc( byval n as long ) as long
declare function retStmt( ) as long
declare sub exitFor( )
declare sub exitWhile( )
declare sub exitDo( )
declare sub exitTwoFors( )
declare sub gotoOutOne( )
declare sub gotoOutThree( )
declare sub neverRegistered( )
declare sub breakWithDtor( )

	'' ==================================================== reverse order, off end scope

	log_ = "" : scopeFallthrough( )
	assert_( log_ = "AB21C" )

	'' ==================================================== off end sub / end function

	log_ = "" : procFallthrough( )
	assert_( log_ = "pyx" )

	log_ = ""
	assert_( funcFallthrough( ) = 5 )
	assert_( log_ = "fyx" )

	'' ==================================================== interleaving with destructors
	''
	'' Both live in ONE list in declaration order, so they interleave rather
	'' than running as two passes. Asserted in both orders because a two-pass
	'' implementation would get exactly one of them right by accident.

	log_ = "" : interleaveDeferFirst( )
	assert_( log_ = "~b[1]~a" )

	log_ = "" : interleaveVarFirst( )
	assert_( log_ = "[2]~b[1]~a" )

	'' ==================================================== a loop body

	'' The defer belongs to the loop body's scope, so it runs on EVERY
	'' iteration, not once at the end of the loop.
	log_ = "" : loopBody( )
	assert_( log_ = "i1L1i2L2i3L3" )

	'' ==================================================== reads a local

	'' The statement runs at scope exit, so it sees the local's value THEN, not
	'' the value it had when the defer was registered.
	log_ = "" : readsLocal( )
	assert_( log_ = "v=9" )

	'' ==================================================== nested scopes

	log_ = "" : nestedScopes( )
	assert_( log_ = "abc<C><B><A>" )

	'' ==================================================== inside IF / SELECT / WITH arms

	log_ = "" : inIfArm( 1 )
	assert_( log_ = "then-body then-defer" )

	log_ = "" : inIfArm( 2 )
	assert_( log_ = "else-body else-defer" )

	log_ = "" : inSelectArm( 1 )
	assert_( log_ = "case1-body case1-defer" )

	log_ = "" : inSelectArm( 2 )
	assert_( log_ = "case2-body case2-defer" )

	'' The trailing "~" is the WITH target's own destructor at 'end sub'. It is
	'' in the expected value on purpose: it proves the defer ran at 'end with',
	'' BEFORE the enclosing procedure's cleanup, rather than being deferred all
	'' the way out to the procedure.
	log_ = "" : inWithBlock( )
	assert_( log_ = "with-body with-defer~" )

	'' ==================================================== many defers

	log_ = "" : manyDefers( )
	assert_( log_ = "9876543210" )

	'' ==================================================== break paths
	''
	'' These leave through astScopeBreak( ) and have their cleanup spliced in
	'' before the JMP by hDestroyBlockLocals( ), which is a different mechanism
	'' from the fallthrough above -- so every form is asserted even though some
	'' expected sequences match.

	log_ = "" : exitSub( 1 )
	assert_( log_ = "D2D1" )

	'' the same procedure falling out of the bottom, for contrast
	log_ = "" : exitSub( 0 )
	assert_( log_ = "tailD2D1" )

	log_ = ""
	assert_( exitFunc( 1 ) = 0 )
	assert_( log_ = "F" )

	log_ = ""
	assert_( retStmt( ) = 7 )
	assert_( log_ = "R" )

	'' 'exit for' from a loop whose BODY registers a defer: the defers already
	'' run for completed iterations, plus the one for the iteration being left
	log_ = "" : exitFor( )
	assert_( log_ = "L1L2" )

	'' NOTE the values: the deferred statement is evaluated AT EXIT, so it sees
	'' i AFTER the increment, not the value i had at registration. This is the
	'' same rule readsLocal( ) pins, restated on a break path because getting it
	'' wrong here would look like an off-by-one in the loop rather than a defer
	'' bug.
	log_ = "" : exitWhile( )
	assert_( log_ = "W1W2" )

	log_ = "" : exitDo( )
	assert_( log_ = "O" )

	'' multi-level 'exit for, for' -- both loop scopes are left at once, and
	'' hDelLocals( ) walks the block.parent chain outward through both
	log_ = "" : exitTwoFors( )
	assert_( log_ = "inner1outer1" )

	'' 'goto' out of one scope, and out of three at once
	log_ = "" : gotoOutOne( )
	assert_( log_ = "G|done" )

	log_ = "" : gotoOutThree( )
	assert_( log_ = "G3G2G1|done" )

	'' a defer that is never reached, because the exit precedes its registration
	log_ = "" : neverRegistered( )
	assert_( log_ = "before" )

	'' break out of a scope that also holds a real destructor: they interleave
	'' on the break path exactly as they do on fallthrough
	log_ = "" : breakWithDtor( )
	assert_( log_ = "[2]~b[1]~a" )

	'' ==================================================== backward compatibility
	''
	'' 'defer' is a CONTEXTUAL keyword, claimed only when the next token begins
	'' a statement. Everything below is a program that predates the feature and
	'' must keep compiling and behaving identically.

	scope
		'' as a local variable, including a self-op -- '+=' lexes as '+' then
		'' '=', so a reject-list of assignment tokens would have mis-read this
		dim defer as long = 3
		defer = 4
		assert_( defer = 4 )
		defer += 5
		assert_( defer = 9 )
		defer -= 1
		assert_( defer = 8 )

		'' as an array
		dim deferArr( 0 to 2 ) as long
		deferArr( 1 ) = 7
		assert_( deferArr( 1 ) = 7 )
	end scope

	'' as a field
	scope
		dim h as HasDeferField
		h.defer = 5
		assert_( h.defer = 5 )
	end scope

	'' as a shared variable
	deferShared = 11
	assert_( deferShared = 11 )

	'' A PROCEDURE named 'defer' is covered by defer-identifier.bas instead:
	'' FreeBASIC refuses a local that shadows a module-level procedure of the
	'' same name ("error 4: Duplicated definition"), which is an ordinary rule
	'' unrelated to DEFER, so the two cases cannot share a module.

'' ---------------------------------------------------------------- fixtures

sub scopeFallthrough( )
	log_ &= "A"
	scope
		defer log_ &= "1"
		defer log_ &= "2"
		log_ &= "B"
	end scope
	log_ &= "C"
end sub

sub procFallthrough( )
	defer log_ &= "x"
	defer log_ &= "y"
	log_ &= "p"
end sub

function funcFallthrough( ) as long
	defer log_ &= "x"
	defer log_ &= "y"
	log_ &= "f"
	function = 5
end function

'' defer registered BEFORE the second variable
sub interleaveDeferFirst( )
	scope
		dim a as Tr : a.nm = "a"
		defer log_ &= "[1]"
		dim b as Tr : b.nm = "b"
	end scope
end sub

'' and with a defer registered after it too
sub interleaveVarFirst( )
	scope
		dim a as Tr : a.nm = "a"
		defer log_ &= "[1]"
		dim b as Tr : b.nm = "b"
		defer log_ &= "[2]"
	end scope
end sub

sub loopBody( )
	for i as long = 1 to 3
		defer log_ &= "L" & i
		log_ &= "i" & i
	next
end sub

sub readsLocal( )
	scope
		dim as long v = 7
		defer log_ &= "v=" & v
		v = 9
	end scope
end sub

sub nestedScopes( )
	scope
		defer log_ &= "<A>"
		log_ &= "a"
		scope
			defer log_ &= "<B>"
			log_ &= "b"
			scope
				defer log_ &= "<C>"
				log_ &= "c"
			end scope
		end scope
	end scope
end sub

sub inIfArm( byval n as long )
	if( n = 1 ) then
		defer log_ &= " then-defer"
		log_ &= "then-body"
	else
		defer log_ &= " else-defer"
		log_ &= "else-body"
	end if
end sub

sub inSelectArm( byval n as long )
	select case( n )
	case 1
		defer log_ &= " case1-defer"
		log_ &= "case1-body"
	case else
		defer log_ &= " case2-defer"
		log_ &= "case2-body"
	end select
end sub

sub inWithBlock( )
	dim t as Tr
	with t
		defer log_ &= " with-defer"
		.nm = ""
		log_ &= "with-body"
	end with
end sub

'' Ten of them, to show the order is a genuine stack rather than a pair swap.
sub manyDefers( )
	scope
		for i as long = 0 to 9
			'' each iteration's defer runs at the end of THAT iteration
		next
		defer log_ &= "0"
		defer log_ &= "1"
		defer log_ &= "2"
		defer log_ &= "3"
		defer log_ &= "4"
		defer log_ &= "5"
		defer log_ &= "6"
		defer log_ &= "7"
		defer log_ &= "8"
		defer log_ &= "9"
	end scope
end sub

'' ---------------------------------------------------------------- break paths

sub exitSub( byval n as long )
	defer log_ &= "D1"
	defer log_ &= "D2"
	if( n = 1 ) then exit sub
	log_ &= "tail"
end sub

function exitFunc( byval n as long ) as long
	defer log_ &= "F"
	if( n = 1 ) then exit function
	return 5
end function

function retStmt( ) as long
	defer log_ &= "R"
	return 7
end function

sub exitFor( )
	for i as long = 1 to 3
		defer log_ &= "L" & i
		if( i = 2 ) then exit for
	next
end sub

sub exitWhile( )
	dim as long i = 0
	while( i < 3 )
		defer log_ &= "W" & i
		i += 1
		if( i = 2 ) then exit while
	wend
end sub

sub exitDo( )
	do
		defer log_ &= "O"
		exit do
	loop
end sub

'' 'exit for, for' leaves BOTH loops in one statement.
sub exitTwoFors( )
	for i as long = 1 to 2
		defer log_ &= "outer" & i
		for j as long = 1 to 2
			defer log_ &= "inner" & j
			exit for, for
		next
	next
end sub

sub gotoOutOne( )
	scope
		defer log_ &= "G"
		goto done_
	end scope
	done_:
	log_ &= "|done"
end sub

sub gotoOutThree( )
	scope
		defer log_ &= "G1"
		scope
			defer log_ &= "G2"
			scope
				defer log_ &= "G3"
				goto done_
			end scope
		end scope
	end scope
	done_:
	log_ &= "|done"
end sub

'' The exit happens BEFORE the defer is registered, so it never runs. The
'' statement-number window in hDestroyBlockLocals( ) is what gets this right.
sub neverRegistered( )
	scope
		log_ &= "before"
		if( 1 = 1 ) then exit sub
		defer log_ &= "SHOULD-NOT-RUN"
	end scope
end sub

sub breakWithDtor( )
	scope
		dim a as Tr : a.nm = "a"
		defer log_ &= "[1]"
		dim b as Tr : b.nm = "b"
		defer log_ &= "[2]"
		exit sub
	end scope
end sub
