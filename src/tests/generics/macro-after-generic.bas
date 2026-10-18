' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic body is preprocessed once, where it is written: the capture runs
'' the preprocessor, so every macro defined at that point is already expanded
'' in the captured tokens.  The replay at each instantiation must not expand
'' macros a second time, or it picks up macros defined AFTER the generic.
''
'' TestKit 1.x had '#macro TEST( suite, name )'; included after a container
'' library, it broke the library's 'xPredicate.Test( byref v as const T )' at
'' every instantiation with "Argument count mismatch, expanding: TEST".  The
'' body is bound where it was written, as C++ templates are.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

#define KBASE 10
#define TWICE( x ) ((x) * 2)

type Pred( of T )
	as T limit
	declare function Test( byref v as const T ) as boolean
	declare function Calc( ) as long
	declare function Helper( ) as long
end type

function Pred( of T ).Test( byref v as const T ) as boolean
	return v < this.limit
end function

'' KBASE and TWICE as they are here, whatever they become below
function Pred( of T ).Calc( ) as long
	return KBASE + TWICE( 3 ) + this.Helper( )
end function

function Pred( of T ).Helper( ) as long
	return 100
end function

function AddBase( of T )( byval x as T ) as T
	return x + KBASE
end function

'' Plain code calling the method has to be written before the macro too --
'' after it, 'Test(' is a macro call, as it should be.  Nothing here
'' instantiates Pred( of double ): that happens below the macros.
function CountBelow( byref p as Pred( of long ), byval n as long ) as long
	dim as long i = 0, c = 0
	while i < n
		if p.Test( i ) then
			c += 1
		end if
		i += 1
	wend
	return c
end function

'' all of these come after the generics and before their instantiations
#macro TEST( a_, b_ )
	sub a_##b_( )
#endmacro
#define HELPER( a_, b_ ) a_ b_
#undef KBASE
#define KBASE 1000
#undef TWICE
#define TWICE( x ) 0

dim as Pred( of long ) p
p.limit = 3
assert_( CountBelow( p, 10 ) = 3 )
assert_( p.Calc( ) = 116 )
assert_( AddBase( 5 ) = 15 )

'' first instantiated here, below every macro
dim as Pred( of double ) q
q.limit = 0.5
assert_( q.Calc( ) = 116 )
assert_( AddBase( 0.5 ) = 10.5 )

'' a lambda written here sees the macros as they are here
var f = function( byval x as long ) as long
	return x + KBASE
end function
assert_( f( 1 ) = 1001 )
