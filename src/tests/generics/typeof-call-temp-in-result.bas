' TEST_MODE : COMPILE_AND_RUN_OK

'' typeof( call ) in a generic procedure's RESULT type, when the call needs a
'' temporary.
''
'' The header is replayed in the instantiation's synthetic namespace, so the
'' temporary that typeof( ) creates (and discards) lands there.  Mangling
'' skipped that namespace but still length-prefixed the id, which made it no
'' name at all:
''
''     -gen gcc:   struct $5PUNCT 6TMP$4$;    error: invalid suffix "TMP$4$"
''     -gen gas:   .lcomm 7LT_0004,32         Error: expected symbol name
''
'' The temporary appears for a result with a destructor (gcc), for any call
'' under -exx (the null-pointer check), and for a result returned through a
'' hidden pointer (fbc32 gas).  Covered: all three, at toplevel and in a
'' namespace (which already mangled correctly), each instantiated twice.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Punct
	as string nume
end type

type Mare
	as double a, b, c, d
end type

type Box( of R )
	as R r
end type

function Run( of F )( byref f as F ) as Box( of typeof( ( *cast( F ptr, 0 ) )( ) ) )
	dim as Box( of typeof( ( *cast( F ptr, 0 ) )( ) ) ) b
	b.r = f( )
	return b
end function

namespace NS
	function RunIn( of F )( byref f as F ) as Box( of typeof( ( *cast( F ptr, 0 ) )( ) ) )
		dim as Box( of typeof( ( *cast( F ptr, 0 ) )( ) ) ) b
		b.r = f( )
		return b
	end function
end namespace

var t1 = Run( function( ) as Punct
	dim as Punct p
	p.nume = "A"
	return p
end function )
assert_( t1.r.nume = "A" )

var t2 = Run( function( ) as Punct
	dim as Punct p
	p.nume = "BC"
	return p
end function )
assert_( t2.r.nume = "BC" )

var t3 = Run( function( ) as Mare
	dim as Mare m
	m.d = 4
	return m
end function )
assert_( t3.r.d = 4 )

var t4 = Run( function( ) as double
	return 1.5
end function )
assert_( t4.r = 1.5 )

var n1 = NS.RunIn( function( ) as Punct
	dim as Punct p
	p.nume = "N"
	return p
end function )
assert_( n1.r.nume = "N" )

var n2 = NS.RunIn( function( ) as Mare
	dim as Mare m
	m.a = 2
	return m
end function )
assert_( n2.r.a = 2 )

dim as long k = 3
var c1 = Run( function[ byval k ]( ) as Punct
	dim as Punct p
	p.nume = string( k, "x" )
	return p
end function )
assert_( c1.r.nume = "xxx" )
