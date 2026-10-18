' TEST_MODE : COMPILE_ONLY_FAIL
/'
	An error that leaves a replayed generic member body unbalanced must still
	end the compile, well before -maxerr.

	'sub' inside a procedure is error 61, and the parser then misreads the
	lines that would have closed the IF, the WHILE and the procedure: the
	replay ran into the end of its text with all three still open.  The
	procedure stayed nested above the instantiation's namespace, the next owed
	body nested that namespace a second time, and the nested-hash list became
	a cycle: fbc printed "Expected 'END IF'" and never exited.

	The open blocks are now closed after such a replay and the compile goes on
	(tests/errors/generic-replay-unbalanced.bas pins what is reported).  If
	this regresses, the suite hangs on this file.
'/

type Box( of T )
	as T v
	declare function Walk( ) as long
	declare sub Other( )
end type

function Box( of T ).Walk( ) as long
	dim as long i = 0
	while i < 3
		if i = 1 then
			sub Bad( )
		end if
		i += 1
	wend
	return i
end function

sub Box( of T ).Other( )
	this.v = this.v
end sub

dim as Box( of long ) b
dim as long k = 0
var f = sub[ byref k ]( )
	k += 1
end sub
f( )
print b.Walk( )
