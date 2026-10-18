'' Errors that leave a replayed generic body unbalanced.
''
'' See readme.txt: this file is compiled for five targets and the output is
'' diffed against the checked-in goldens under r/.
''
'' 'sub' inside a procedure (error 61) makes the parser misread the lines that
'' would have closed the blocks around it, so the replay reaches the end of its
'' text with them still open.  Each case must report its own errors once, with
'' no leftovers at the end of this file ("Expected 'END IF'" in the main code),
'' and must not stop the errors after it from being reported.  The compiler
'' before this hung on the first case.

#print === IF, FOR and WHILE left open in a member body ===
type A( of T )
	as T v
	declare function Walk( ) as long
	declare sub Other( )
end type

function A( of T ).Walk( ) as long
	dim as long i = 0
	while i < 3
		for j as long = 0 to 1
			if i = 1 then
				sub Bad( )
			end if
		next
		i += 1
	wend
	return i
end function

sub A( of T ).Other( )
	this.v = nosuchvar1
end sub

dim aa as A( of long )

#print === procedure left open in a generic procedure ===
function Twice( of T )( byval x as T ) as T
	sub Bad2( )
	return x * 2
end function

dim as long t2 = Twice( 3 )

#print === later code still compiles, later errors are still reported ===
dim as long k = 0
var f = sub[ byref k ]( )
	k += 1
end sub
f( )

sub Plain( )
	print nosuchvar2
end sub

print nosuchvar3

#print === macro defined after the generic is not expanded in its body ===
type P( of T )
	as T x
	declare function Test( byref v as const T ) as boolean
end type

function P( of T ).Test( byref v as const T ) as boolean
	return v = v
end function

#macro TEST( a_, b_ )
	sub a_##b_( )
#endmacro

dim pp as P( of long )
print pp.nosuchfield
