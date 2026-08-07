' TEST_MODE : COMPILE_AND_RUN_OK

'' '_' line continuations inside captured generic text.
''
'' A captured chain has no record of the '_' -- the lexer hides it, and only the
'' line number advances.  Rebuilding the text therefore has to tell a line that
'' the source really ended from one it merely continued: closing a continued line
'' with a newline splits a parameter list or an expression in half, and because
'' the failure happens in the replayed text it is only reported at instantiation,
'' pointing at the generic's declaration rather than at the offending line.
''
'' Every construct here compiles if -- and only if -- its continuation survives
'' the round trip, so a regression is a compile error, not a wrong answer.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ----------------------------------------------------------------------------
'' generic procedures: the header is captured separately from the body
'' ----------------------------------------------------------------------------

'' parameter list split, and the return type on a further line
function Add3( of T ) _
	( _
		byval a as T, _
		byval b as T, _
		byval c as T _
	) as T

	return a + b + c
end function

'' the split is in the BODY, not the header
function SumSplit( of T )( byval a as T, byval b as T ) as T
	dim as T r = a + _
	             b
	return r
end function

'' continuation across more than one line, and one inside a compound statement
function Classify( of T )( byval a as T ) as string
	if a > 0 andalso _
	   a < 10 andalso _
	   a <> 5 then
		return "small"
	end if
	return "other"
end function

'' a continuation immediately before the terminator
sub Bump( of T )( byref a as T )
	a = a + _
	    1
end sub

'' ----------------------------------------------------------------------------
'' generic types: the whole body is one captured chain
'' ----------------------------------------------------------------------------

type Holder( of T )
	as T v

	declare sub SetTwo( byval x as T, _
	                    byval y as T )

	declare function Total( ) as T

	as T w
end type

'' the out-of-line body's own header is captured too
sub Holder( of T ).SetTwo( byval x as T, _
                           byval y as T )
	this.v = x
	this.w = y
end sub

function Holder( of T ).Total( ) as T
	return this.v + _
	       this.w
end function

'' ----------------------------------------------------------------------------

	assert_( Add3( of long )( 1, 2, 3 ) = 6 )
	assert_( Add3( 1, 2, 3 ) = 6 )
	assert_( Add3( of double )( 0.5, 0.25, 0.25 ) = 1.0 )

	assert_( SumSplit( of long )( 4, 5 ) = 9 )

	assert_( Classify( of long )( 3 ) = "small" )
	assert_( Classify( of long )( 5 ) = "other" )
	assert_( Classify( of long )( 50 ) = "other" )

	dim as long n = 41
	Bump( of long )( n )
	assert_( n = 42 )

	dim h as Holder( of long )
	h.SetTwo( 20, 22 )
	assert_( h.v = 20 )
	assert_( h.w = 22 )
	assert_( h.Total( ) = 42 )

	dim hd as Holder( of double )
	hd.SetTwo( 1.5, 2.5 )
	assert_( hd.Total( ) = 4.0 )
