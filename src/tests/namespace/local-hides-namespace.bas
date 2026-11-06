' TEST_MODE : COMPILE_AND_RUN_OK

'' A local may have the name of a namespace, and hides it while in scope.
''
'' With 'namespace K' declared, every 'dim k', 'for k as long', parameter 'k'
'' and 'var k' anywhere failed -- Expected period, or Duplicated definition --
'' because the name could only mean the namespace.  That broke a library's
'' generic body as soon as the program had a namespace named like one of its
'' locals: FB.Array( of T ) in 'namespace K' failed on fb/array.bi's own
'' 'for k as long'.  As in C++, a local (a procedure's, a parameter, a SCOPE
'' block's) now hides a namespace of the same name; a module-level variable in
'' the namespace's own scope is still a duplicate.

#include once "fb/array.bi"

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

namespace K
	dim shared as long v = 42
	function F( ) as long
		return 7
	end function
	type Item
		as long n
	end type
	'' the original report: a library generic instantiated in a one-letter
	'' namespace, whose body has a local of that name
	dim shared as FB.Array( of Item ) items
end namespace

function ForAs( ) as long
	dim as long s = 0
	for k as long = 1 to 3
		s += k
	next
	return s
end function

function DimLocal( ) as long
	dim as long k = 5
	k += 1
	return k
end function

function DimSecondForm( ) as string
	dim k as string = "s"
	return k & k
end function

function Param( byval k as long ) as long
	return k * 2
end function

function VarLocal( ) as double
	var k = 3.5
	return k
end function

'' with no local k, the namespace is reached as before
function Qualified( ) as long
	return K.v + K.F( )
end function

'' a local k (not a UDT, so it has no members) and K.v, K.F( ) side by side
function Mixed( ) as long
	dim as long k = 1
	return k + K.v + K.F( )
end function

'' a SCOPE block's local at module level
scope
	dim as long k = 9
	assert_( k = 9 )
	assert_( K.v = 42 )
end scope

assert_( ForAs( ) = 6 )
assert_( DimLocal( ) = 6 )
assert_( DimSecondForm( ) = "ss" )
assert_( Param( 21 ) = 42 )
assert_( VarLocal( ) = 3.5 )
assert_( Qualified( ) = 49 )
assert_( Mixed( ) = 50 )

scope
	dim as K.Item it
	it.n = 5
	K.items.Push( it )
	K.items.Push( it )
	assert_( K.items.Count( ) = 2 )
	dim as long total = 0
	for each x in K.items
		total += x.n
	next
	assert_( total = 10 )
end scope
