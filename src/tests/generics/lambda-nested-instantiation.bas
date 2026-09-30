' TEST_MODE : COMPILE_AND_RUN_OK

'' Two lambdas in one statement, the second instantiating a generic that the
'' first one's instantiation already needs -- a chain of lazy views:
''
''     WhereOn( Where1( src, lambda1 ), lambda2 )
''
'' A lambda's header is replayed at once, in the middle of the expression, and
'' that replay runs cProgram( ), whose statement boundaries drained pending
'' generic member bodies.  The second lambda's header replay therefore compiled
'' the bodies of WIter( of long, It, <lambda1's type> ) with the parser still
'' inside the user's expression: FB_PARSEROPT_ISEXPR was set, and every SUB
'' call in statement position in those bodies -- 'this.Skip( )',
'' 'this.it_.MoveNext( )' -- was refused with 'error 17: Syntax error'.
'' The same chain built from procedure pointers, or over two statements,
'' worked.  Bodies are now drained only at a real statement boundary.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type It( of T )
	as T ptr p
	as long i, n
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type
function It( of T ).IsValid( ) as boolean : return this.i < this.n : end function
function It( of T ).Value( ) byref as T : return this.p[ this.i ] : end function
sub It( of T ).MoveNext( ) : this.i += 1 : end sub

type WIter( of T, I, F )
	as I it_
	as F pred_
	declare sub Skip( )
	declare constructor( )
	declare constructor( byref it as I, byval pred as F )
	declare function IsValid( ) as boolean
	declare function Value( ) byref as T
	declare sub MoveNext( )
end type
constructor WIter( of T, I, F )( )
end constructor
constructor WIter( of T, I, F )( byref it as I, byval pred as F )
	this.it_ = it
	this.pred_ = pred
	this.Skip( )
end constructor
sub WIter( of T, I, F ).Skip( )
	while this.it_.IsValid( ) andalso this.pred_( this.it_.Value( ) ) = false
		this.it_.MoveNext( )
	wend
end sub
function WIter( of T, I, F ).IsValid( ) as boolean : return this.it_.IsValid( ) : end function
function WIter( of T, I, F ).Value( ) byref as T : return this.it_.Value( ) : end function
sub WIter( of T, I, F ).MoveNext( )
	this.it_.MoveNext( )
	this.Skip( )
end sub

type WView( of T, I, F )
	as I src_
	as F pred_
	declare constructor( )
	declare constructor( byref src as I, byval pred as F )
	declare function GetIterator( ) as WIter( of T, I, F )
end type
constructor WView( of T, I, F )( )
end constructor
constructor WView( of T, I, F )( byref src as I, byval pred as F )
	this.src_ = src : this.pred_ = pred
end constructor
function WView( of T, I, F ).GetIterator( ) as WIter( of T, I, F )
	return WIter( of T, I, F )( this.src_, this.pred_ )
end function

function Where1( of T, F )( byref src as It( of T ), byval pred as F ) as WView( of T, It( of T ), F )
	return WView( of T, It( of T ), F )( src, pred )
end function
function WhereOn( of T, I, F, G )( byref v as WView( of T, I, F ), byval pred as G ) as WView( of T, WIter( of T, I, F ), G )
	return WView( of T, WIter( of T, I, F ), G )( v.GetIterator( ), pred )
end function

dim as long arr( 0 to 4 ) = { 1, 2, 3, 4, 5 }
dim as It( of long ) src : src.p = @arr( 0 ) : src.n = 5

'' the first instantiation of the whole chain, in one statement
dim as long sum = 0, n = 0
for each v as long in WhereOn( Where1( src, function( byval x as long ) as boolean : return x > 1 : end function ), _
                               function( byval x as long ) as boolean : return x < 5 : end function )
	sum += v : n += 1
next
assert_( n = 3 )
assert_( sum = 2 + 3 + 4 )

'' the same chain again, held in a variable, with lambdas over several lines
var w = WhereOn( Where1( src, function( byval x as long ) as boolean
		return x <> 3
	end function ), function( byval x as long ) as boolean
		return x > 1
	end function )
sum = 0 : n = 0
for each v as long in w
	sum += v : n += 1
next
assert_( n = 3 )
assert_( sum = 2 + 4 + 5 )

'' inside a procedure: the drain waits for the module-level boundary after it
function Count3( byref s as It( of long ) ) as long
	dim as long c = 0
	for each v as long in WhereOn( Where1( s, function( byval x as long ) as boolean : return x >= 2 : end function ), _
	                               function( byval x as long ) as boolean : return x <= 4 : end function )
		c += 1
	next
	return c
end function
assert_( Count3( src ) = 3 )
