' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic instantiated by its QUALIFIED name, from outside its namespace.
''
'' What a generic body can see is fixed where the generic is DECLARED, not where
'' it happens to be used.  An instantiation is built in the global namespace
'' (parser-generic.bas, genEnterGlobalScope -- a UDT with member procedures
'' cannot be built below module level), so without the declaring namespace on the
'' search chain the body loses every unqualified name it owns: a sibling generic,
'' a const, a plain type.
''
'' This went unnoticed because every other test and every doc example writes
'' 'using FB' first, which puts the namespace on the search chain for an entirely
'' unrelated reason and made the replay find those names by accident of the
'' CALLER's scope.  So the qualified form -- 'dim x as FB.Array( of string )',
'' the one a user writes before reaching for 'using' -- was the untested path,
'' and it did not compile.
''
'' Both spellings are asserted here, in both orders, because the fix is
'' refcounted and the interesting failure is a double-push or an unmatched pop
'' leaving the chain skewed for whatever comes next.

#include once "containers.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

namespace NS

	const CAP as long = 4

	'' referenced unqualified by Box's body, from the same namespace
	type Inner( of T )
		as T v
		declare function Get( ) as T
	end type

	function Inner( of T ).Get( ) as T
		return this.v
	end function

	type Plain
		as long n
	end type

	'' body reaches for all three: a namespace const, a sibling generic, and a
	'' plain type declared in the same namespace
	type Box( of T )
		as T items( 0 to CAP-1 )
		as Inner( of T ) boxed
		as Plain tag
		declare function GetCap( ) as long
	end type

	function Box( of T ).GetCap( ) as long
		return CAP
	end function

end namespace

'' ---------------------------------------------------------------- qualified

'' The whole point: no 'using NS' anywhere above this line.
dim as NS.Box( of string ) qb
qb.items(0) = "ada"
qb.boxed.v  = "grace"
qb.tag.n    = 7

assert_( qb.GetCap( ) = 4 )
assert_( qb.items(0) = "ada" )
assert_( qb.boxed.Get( ) = "grace" )
assert_( qb.tag.n = 7 )

'' a second, distinct instantiation by the qualified name
dim as NS.Box( of long ) ql
ql.items(3) = 99
ql.boxed.v  = 42
assert_( ql.GetCap( ) = 4 )
assert_( ql.items(3) = 99 )
assert_( ql.boxed.Get( ) = 42 )

'' the sibling generic reached directly, qualified
dim as NS.Inner( of double ) qi
qi.v = 1.5
assert_( qi.Get( ) = 1.5 )

'' ---------------------------------------------- the shipped containers, too

'' This is the form that was broken for every user of containers.bi.
dim names as FB.Array( of string )
names.Push( "ada" )
names.Push( "grace" )
assert_( names.Count( ) = 2 )
assert_( names[ 0 ] = "ada" )

dim ages as FB.Map( of string, long )
ages[ "ada" ] = 36
assert_( ages.Count( ) = 1 )
assert_( ages[ "ada" ] = 36 )

dim seen as FB.Set( of long )
seen.Add( 3 )
assert_( seen.Contains( 3 ) )

dim q as FB.LinkedList( of string )
q.PushBack( "tail" )
assert_( q.Count( ) = 1 )

'' USTRING as a type argument, qualified -- exercised because the string library
'' hands back an Array( of ustring ) and nothing else covers this pairing.
dim words as FB.Array( of ustring )
words.Push( "h" & wchr( 233 ) & "llo" )
assert_( words.Count( ) = 1 )
assert_( len( words[ 0 ] ) = 5 )

'' ------------------------------------------- unqualified, after the above

'' The refcount must have come back to where it started: 'using' still works,
'' and it still works for a namespace the qualified path already pushed and
'' popped.
using NS
using FB

dim as Box( of string ) ub
ub.items(1) = "edsger"
assert_( ub.GetCap( ) = 4 )
assert_( ub.items(1) = "edsger" )

'' the SAME argument list as the qualified one above -- must hit the cache and
'' be the same type, not a second instantiation
dim as Box( of string ) ub2 = qb
assert_( ub2.items(0) = "ada" )
assert_( ub2.boxed.Get( ) = "grace" )

dim more as Array( of string )
more.Push( "hopper" )
assert_( more.Count( ) = 1 )

'' and a NEW instantiation raised unqualified, after all the pushing and popping
dim as Box( of single ) ubs
ubs.items(2) = 2.5f
assert_( ubs.GetCap( ) = 4 )
assert_( ubs.items(2) = 2.5f )

dim flags as Array( of boolean )
flags.Push( true )
assert_( flags.Count( ) = 1 )

print "namespace-qualified-inst: ok"
