'' Module B -- the same shape as module A on purpose.

#include once "lambda-generic-mm.bi"

function LgmModuleB( ) as long
	var f = LgmPlain( 1l )
	dim as LgmBox( of long ) b
	b.v = 2
	return f( 2 ) + LgmCapture( 2l ) + b.Apply( ) + LgmPrivate( )
end function
