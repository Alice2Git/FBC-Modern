' TEST_MODE : COMPILE_AND_RUN_OK

'' DEFER -- phase 3: registration, and the FALLTHROUGH exits only.
''
'' Covered here: reverse order, fallthrough off 'end scope' and off
'' 'end sub'/'end function', a defer in a loop body, interleaving with real
'' destructors in both orders, reading a local declared before the defer, defers
'' inside IF/SELECT/WITH arms, and backward compatibility for code that uses
'' 'defer' as an identifier.
''
'' NOT covered here, because phase 3 does not implement it: the break paths --
'' 'exit sub', 'return', 'exit for/while/do' and 'goto' out of a scope. Those go
'' through astScopeBreak( ) and hDestroyBlockLocals( ), and phase 4 adds them.
'' The assertions below are all on paths that fall out of the bottom.
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
