'' Module A. Deliberately the SAME SHAPE as module B, so the two would collide
'' if synthesised names were not module-unique.

function ModuleA( ) as long
	dim f as function( byval x as long ) as long = _
		function( byval x as long ) as long : return x + 1 : end function
	return f( 10 )
end function

function ModuleACapture( ) as long
	dim as long acc = 0
	var c = sub[ byref acc ]( byval v as long ) : acc += v : end sub
	c( 10 )
	return acc
end function
