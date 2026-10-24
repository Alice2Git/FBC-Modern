'' Header for lambda-generic-mm.bmk: generics with lambdas in their bodies, and
'' a private procedure with one -- each included by both modules.

#pragma once

type LgmFn as function( byval x as long ) as long

function LgmPlain( of T )( byval v as T ) as LgmFn
	return function( byval x as long ) as long
		return x + sizeof( T )
	end function
end function

function LgmCapture( of T )( byval v as T ) as long
	dim as long k = 10
	var f = function[ byval k ]( byval x as T ) as long
		return k + x
	end function
	return f( v )
end function

type LgmBox( of T )
	as T v
	declare function Apply( ) as long
end type

function LgmBox( of T ).Apply( ) as long
	var f = function( byval x as long ) as long
		return x * 3
	end function
	return f( this.v )
end function

private function LgmPrivate( ) as long
	var f = function( byval x as long ) as long
		return x * 2
	end function
	return f( 21 )
end function
