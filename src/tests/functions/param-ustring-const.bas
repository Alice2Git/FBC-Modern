' TEST_MODE : COMPILE_AND_RUN_OK

'' A CONST argument passed to a BYREF AS CONST USTRING parameter.
''
'' A non-ustring argument reaches a BYREF USTRING parameter through a temp
'' ustring, and for a BYREF parameter the temp used to be copied back into the
'' argument after the call -- even for a CONST parameter, which the callee
'' cannot change.  The copy-back is only built when the procedure is emitted,
'' and for a CONST argument it failed the CONST check there:
''
''     sub UseU( byref u as const ustring )
''     end sub
''     type T
''         as string txt
''     end type
''     sub F( byref c as const T )
''         UseU( c.txt )
''     end sub                 '' error 181 ... at parameter 1 in 'end sub'
''
'' The error named END SUB, not the call.  A BYREF AS CONST USTRING parameter
'' now gets no copy-back at all.  A non-CONST parameter still copies back, and
'' still refuses a CONST argument at the call itself.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as ustring seen

sub UseU( byref u as const ustring )
	seen = u
end sub

sub UseUMut( byref u as ustring )
	u = ucase( u )
end sub

type T
	as string txt
	as zstring * 8 z
	as string * 7 f    '' not * 8: see the note at the end
	as wstring * 8 w
	as ustring * 8 uf
end type

'' every string field type of a CONST UDT
sub FromConstUdt( byref c as const T )
	UseU( c.txt ) : assert_( seen = "txt" )
	UseU( c.z )   : assert_( seen = "zst" )
	UseU( c.f )   : assert_( seen = "fix    " )
	UseU( c.w )   : assert_( seen = "wst" )
	UseU( c.uf )  : assert_( seen = "ufx" )
end sub

'' a CONST string parameter passed on
sub FromConstParam( byref s as const string )
	UseU( s ) : assert_( seen = s )
end sub

function FromConstUdtFunc( byref c as const T ) as integer
	UseU( c.txt )
	function = len( seen )
end function

dim as T x
x.txt = "txt"
x.z = "zst"
x.f = "fix"
x.w = "wst"
x.uf = "ufx"

FromConstUdt( x )
assert_( x.txt = "txt" )
assert_( x.z = "zst" )
assert_( x.f = "fix    " )
assert_( x.w = "wst" )
assert_( x.uf = "ufx" )

FromConstParam( "abc" )

'' UTF-8 in the narrow argument still converts on the way in
x.txt = "a" + chr( &hC3, &hA9 )
assert_( FromConstUdtFunc( x ) = 2 )
assert_( seen[1] = &hE9 )
assert_( len( x.txt ) = 3 )

'' a CONST local
scope
	dim as const string cs = "local"
	UseU( cs ) : assert_( seen = "local" )
end scope

'' a non-CONST parameter still copies back into a non-CONST argument
x.txt = "low"
x.f = "fix"
UseUMut( x.txt ) : assert_( x.txt = "LOW" )
UseUMut( x.f )   : assert_( x.f = "FIX    " )

'' The field is STRING * 7 rather than * 8 because of a separate gas64 bug: a
'' STRING * 8 next to a STRING (field or variable) makes the program crash or
'' lose the STRING's value there, with or without USTRING involved.
