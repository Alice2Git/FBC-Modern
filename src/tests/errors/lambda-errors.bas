'' Lambda diagnostics.

type Fn as function( byval x as long ) as long

#print === a capture with no mode ===
sub noMode( )
	dim as long t = 0
	var f = sub[ t ]( ) : end sub
end sub

#print === a capture naming an undeclared variable ===
sub undeclared( )
	var f = sub[ byref nosuchthing ]( ) : end sub
end sub

#print === a capturing lambda converted to a procedure pointer ===
sub toProcPtr( )
	dim as long bias = 1
	dim f as Fn = function[ byval bias ]( byval x as long ) as long : return x : end function
end sub

'' NOT pinned here: errors 350 (malformed header) and 351 (unterminated body)
'' need EOF to arrive inside the lambda, which would swallow the rest of the
'' file and every case above it. An 'end sub' that is merely the WRONG one is
'' consumed as the lambda's own terminator, so it surfaces as the enclosing
'' procedure being unterminated rather than as a lambda diagnostic.
