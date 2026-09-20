' TEST_MODE : COMPILE_AND_RUN_OK

'' Lambda bodies must be parsed in the context they were WRITTEN in.
''
'' A lambda's body is replayed at the next module-level statement boundary.
'' A generic body replay has statement boundaries of its own, and it used to
'' drain every pending lambda there -- with that instantiation's type
'' parameters in scope. FreeBASIC is case-insensitive, so a lambda parameter
'' named 't' lost to the type parameter 'T': 'len( t )' silently became
'' 'len( T )', the size of the TYPE, and anything that needed 't' as a value
'' failed with "Variable not declared".
''
'' The lambda did not have to be an argument of that generic: any lambda still
'' pending when ANY generic body was replayed was affected -- earlier in the
'' same statement, or anywhere earlier in the same procedure.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type StrPred as function( byref as const string ) as boolean
type LongFn as function( byval x as long ) as long

dim shared as long hits

sub Apply( of T, F )( byref a as T, byref b as T, byval pred as F )
	if pred( a ) then hits += 1
	if pred( b ) then hits += 1
end sub

sub ApplyA( of A, F )( byref x as A, byref y as A, byval pred as F )
	if pred( x ) then hits += 1
	if pred( y ) then hits += 1
end sub

function Id( of T )( byref v as T ) as T
	return v
end function

function Check( byval p as StrPred, byref s as const string ) as boolean
	return p( s )
end function

dim shared as string sx, sy
sx = "ana"
sy = "maria"

'' ============================================ inline argument of the generic

'' the original report: parameter 't', generic parameter 'T'
hits = 0
Apply( sx, sy, function( byref t as const string ) as boolean : return len( t ) > 3 : end function )
assert_( hits = 1 )

'' same, parameter 'a' against generic parameter 'A'
hits = 0
ApplyA( sx, sy, function( byref a as const string ) as boolean : return len( a ) > 3 : end function )
assert_( hits = 1 )

'' 't' used as a VALUE, where it used to be "Variable not declared"
hits = 0
Apply( sx, sy, function( byref t as const string ) as boolean : return t <> "ana" : end function )
assert_( hits = 1 )

'' a different type argument -- a fresh instantiation, so a fresh replay
dim shared as long lx, ly
lx = 1
ly = 100000
hits = 0
Apply( lx, ly, function( byref t as const long ) as boolean : return t > 5 : end function )
assert_( hits = 1 )

'' ============================== an UNRELATED generic in the same statement

'' the lambda is queued before Id( of short ) is instantiated
dim shared as boolean r1
dim shared as short r2
r1 = Check( function( byref t as const string ) as boolean : return len( t ) > 3 : end function, "ana" ) : r2 = Id( cshort( 5 ) )
assert_( r1 = false )
assert_( r2 = 5 )

'' =============================================== inside a procedure

'' nothing is drained until 'end sub', so a generic instantiated LATER in the
'' procedure, in another statement, used to capture the lambda too
sub InsideProc( )
	dim p as StrPred = function( byref t as const string ) as boolean : return len( t ) > 3 : end function
	assert_( p( "ana" ) = false )
	assert_( p( "maria" ) = true )
	assert_( Id( cbyte( 7 ) ) = 7 )
end sub
InsideProc( )

sub InsideProcInline( )
	dim as string u = "ana", v = "maria"
	hits = 0
	Apply( u, v, function( byref t as const string ) as boolean : return len( t ) > 3 : end function )
	assert_( hits = 1 )
end sub
InsideProcInline( )

'' ========================== a lambda written INSIDE a generic keeps its 'T'

'' A generic TYPE body is parsed by cTypeDecl( ), which has no statement
'' boundary, so this lambda is drained from module level after the replay has
'' ended. Its body must still see that instantiation's 'T' -- and must still be
'' defined as the GLOBAL procedure its prototype declared, not as a member of
'' the instance namespace (that was a link error: undefined reference).
type Box( of T )
	v as T
	f as LongFn = function( byval x as long ) as long : return x + sizeof( T ) : end function
end type

scope
	dim b as Box( of short )
	dim c as Box( of double )
	assert_( b.f( 40 ) = 42 )
	assert_( c.f( 40 ) = 48 )
end scope
