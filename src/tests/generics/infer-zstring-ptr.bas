' TEST_MODE : COMPILE_AND_RUN_OK

'' Type-argument inference from a ZSTRING PTR / WSTRING PTR argument.
''
'' Every inferred call with a 'zstring ptr' argument failed:
''
''     error 58: Type mismatch, at parameter 1 of __FBGENPROC() in 'print ByValN( zp )'
''
'' hBindPattern() turns a string LITERAL's zstring / fixed-length type into
'' STRING (see the comment there), and tested that with typeGetDtOnly(), which
'' drops the pointer levels: 'zstring ptr' was bound as STRING too.  Only the
'' pointee, not a pointer to it, may be normalised.
''
'' Reported by TestKit as b01.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

function ByValN( of A )( byval a as A ) as A
	return a
end function

function ByRefN( of A )( byref a as A ) as A
	return a
end function

function ByRefC( of A )( byref a as const A ) as A
	return a
end function

'' '*a' only compiles if A really is a pointer
function DerefText( of A )( byval a as A ) as string
	return *a
end function

'' 'T ptr' binds T to the pointee: zstring
function FirstChar( of T )( byval p as T ptr ) as long
	return p[0]
end function

'' both positions have to bind the same 'zstring ptr'
function SameText( of A )( byval a as A, byval b as A ) as integer
	return *a = *b
end function

'' two type parameters, as in TestKit's tst_Eq( of A, B )
function Pick( of A, B )( byref a as const A, byref b as const B ) as A
	return a
end function

dim as zstring * 8 z = "abc"
dim as zstring ptr zp = @z
dim as wstring * 8 w = wstr( "xyz" )
dim as wstring ptr wp = @w
dim as long l = 7
dim as long ptr lp = @l

assert_( ByValN( zp ) = zp )
assert_( ByRefN( zp ) = zp )
assert_( ByRefC( zp ) = zp )
assert_( ByValN( wp ) = wp )
assert_( ByRefC( wp ) = wp )
assert_( ByRefC( lp ) = lp )

assert_( DerefText( zp ) = "abc" )
assert_( FirstChar( zp ) = asc( "a" ) )
assert_( FirstChar( wp ) = asc( "x" ) )

dim as zstring * 8 z2 = "abc"
assert_( SameText( zp, @z2 ) )

assert_( Pick( zp, lp ) = zp )

'' explicit type arguments were always fine
assert_( ByValN( of zstring ptr )( zp ) = zp )

'' the literal normalisation itself still applies: 'string', not 'zstring'
assert_( ByValN( "lit" ) = "lit" )
assert_( len( ByValN( "lit" ) ) = 3 )
