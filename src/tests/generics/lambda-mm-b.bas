'' Module B -- the same shape as module A on purpose.

function ModuleB( ) as long
	dim f as function( byval x as long ) as long = _
		function( byval x as long ) as long : return x + 2 : end function
	return f( 20 )
end function

function ModuleBCapture( ) as long
	dim as long acc = 0
	var c = sub[ byref acc ]( byval v as long ) : acc += v : end sub
	c( 20 )
	return acc
end function
