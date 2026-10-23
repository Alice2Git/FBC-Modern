' TEST_MODE : COMPILE_AND_RUN_OK

'' Calling a capturing lambda kept in a FIELD.
''
'' A capturing lambda's value is a closure struct, and 'f( )' is a call to its
'' __FBINVOKE.  That was rewritten for a variable ('f( )') and for a
'' parenthesised expression ('( this.fn )( )'), but not after a member access:
'' 'this.fn( )' left the '(' after the field, and as a statement reported
'' "error 10: Expected '='".  Every member access now calls it the same way --
'' '.', '->', WITH, nested fields, array fields, inside generics.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim as long x = 0
var inc = sub[ byref x ]( ) : x += 1 : end sub
var mul = function[ byref x ]( byval k as long ) as long : return x * k : end function

type Holder
	as typeof( inc ) fn
	as typeof( mul ) gn
	as typeof( inc ) arr( 0 to 1 )
	declare sub Go( )
	declare function Twice( ) as long
end type

sub Holder.Go( )
	this.fn( )
	fn( )
	with this
		.fn( )
	end with
end sub

function Holder.Twice( ) as long
	with this
		return .gn( 2 ) + this.gn( 0 )
	end with
end function

dim as Holder h = ( inc, mul, { inc, inc } )

'' in methods: this.fn( ), fn( ), WITH
h.Go( )
assert_( x = 3 )
assert_( h.Twice( ) = 6 )

'' through a variable, a pointer, a nested field, an array field
h.fn( )
assert_( x = 4 )
dim as Holder ptr p = @h
p->fn( )
assert_( x = 5 )
assert_( p->gn( 1 ) + h.gn( 1 ) = 10 )

type Outer
	as Holder h
end type
dim as Outer o
o.h = h
o.h.fn( )
assert_( x = 6 )
assert_( o.h.gn( 3 ) = 18 )
h.arr( 1 )( )
assert_( x = 7 )

'' a BYREF parameter
sub ByRefCall( byref hh as Holder )
	hh.fn( )
end sub
ByRefCall( h )
assert_( x = 8 )

'' in a generic member body: the field's type is the type parameter
type Box( of F )
	as F fn
	declare sub Run( )
end type

sub Box( of F ).Run( )
	this.fn( )
	fn( )
	with this
		.fn( )
	end with
end sub

function MakeBox( of F )( byref f as F ) as Box( of F )
	dim as Box( of F ) b
	b.fn = f
	return b
end function

dim as long n = 5
var b = MakeBox( sub[ byref n ]( ) : n += 1 : end sub )
b.Run( )
assert_( n = 8 )
b.fn( )
assert_( n = 9 )

'' a non-capturing lambda in a field is a procptr, and still works
type PHolder
	as function( byval k as long ) as long fp
end type
dim as PHolder ph
ph.fp = function( byval k as long ) as long : return k + 1 : end function
assert_( ph.fp( 41 ) = 42 )
