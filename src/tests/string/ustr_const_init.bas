' TEST_MODE : COMPILE_AND_RUN_OK

'' A CONST USTRING variable can be initialized.
''
'' The initializer passed the destination to the rtlib assign with its CONST
'' bit, so 'dim as const ustring s = "x"' failed with error 181 at parameter 1,
'' and so did 'var s = f( )' with f returning BYREF AS CONST USTRING -- VAR
'' keeps the CONST of its initializer, as it does for STRING.  That broke
'' 'for each s in a' over an xArray( of ustring ), whose iterator's Value( )
'' returns BYREF AS CONST T.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as ustring g
g = "global"

function RefConst( ) byref as const ustring
	return g
end function

function RefMut( ) byref as ustring
	return g
end function

function ByVal_( ) as ustring
	return g
end function

dim shared as string gnarrow
gnarrow = "narrow"

function RefConstStr( ) byref as const string
	return gnarrow
end function

'' ------------------------------------------- DIM AS CONST USTRING = ...

scope
	dim as const ustring a = "literal"
	assert_( a = "literal" )

	dim as const ustring b = RefConst( )
	assert_( b = "global" )

	dim as const ustring c = a
	assert_( c = "literal" )
	assert_( len( c ) = 7 )
end scope

'' ---------------------------------------------- VAR from every source

scope
	var a = RefConst( )
	assert_( a = "global" )

	var b = RefMut( )
	assert_( b = "global" )
	b = "changed"
	assert_( b = "changed" )
	assert_( g = "global" )

	var c = ByVal_( )
	assert_( c = "global" )

	dim as const ustring k = "k"
	var d = k
	assert_( d = "k" )
end scope

'' ------------------- the copy is a copy, not a reference to the source

scope
	var a = RefConst( )
	g = "after"
	assert_( a = "global" )
	assert_( RefConst( ) = "after" )
	g = "global"
end scope

'' ----------------------- conversions in an initializer of a CONST var

scope
	dim as const string s = RefConst( )
	assert_( s = "global" )

	dim as const ustring u = RefConstStr( )
	assert_( u = "narrow" )
end scope

'' ------------------------------ FOR EACH over a BYREF AS CONST USTRING

type Lista
	as ustring s( 0 to 1 )
	declare const function At( byval i as long ) byref as const ustring
end type
const function Lista.At( byval i as long ) byref as const ustring
	return s( i )
end function

type ListaIt
	as const Lista ptr l
	as long i
	declare function IsValid( ) as boolean
	declare function Value( ) byref as const ustring
	declare sub MoveNext( )
end type
function ListaIt.IsValid( ) as boolean : return i <= 1 : end function
function ListaIt.Value( ) byref as const ustring : return l->At( i ) : end function
sub ListaIt.MoveNext( ) : i += 1 : end sub

type Colectie
	as Lista l
	declare function GetIterator( ) as ListaIt
end type
function Colectie.GetIterator( ) as ListaIt
	dim r as ListaIt : r.l = @l : return r
end function

scope
	dim as Lista l
	l.s( 0 ) = "a" : l.s( 1 ) = "b"
	var y = l.At( 1 )
	assert_( y = "b" )

	dim as Colectie c
	c.l.s( 0 ) = "x" : c.l.s( 1 ) = "y"
	dim as ustring seen
	for each s in c
		seen &= s & ";"
	next
	assert_( seen = "x;y;" )
end scope
