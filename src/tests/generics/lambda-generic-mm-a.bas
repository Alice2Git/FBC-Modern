'' Module A. Deliberately the SAME SHAPE as module B, so the two would collide
'' if the lambdas from the header were public.

#include once "lambda-generic-mm.bi"

function LgmModuleA( ) as long
	var f = LgmPlain( 1l )
	dim as LgmBox( of long ) b
	b.v = 1
	return f( 1 ) + LgmCapture( 2l ) + b.Apply( ) + LgmPrivate( )
end function
