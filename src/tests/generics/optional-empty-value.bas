' TEST_MODE : COMPILE_AND_RUN_FAIL

'' FB.Optional( of T ).Value( ) on an EMPTY Optional must raise.
''
'' This is a separate module because the raise aborts the process, so it cannot
'' share a binary with container-optional.bas.  COMPILE_AND_RUN_FAIL means the
'' harness requires a clean compile and a NON-ZERO exit code.
''
'' The everything-worked path below would exit 0 and fail this test, so the
'' assertion is really "control never reaches the end".

#include once "fb/optional.bi"
using FB

dim o as Optional( of long )

'' Guard: the state must actually be empty, or this file would be testing
'' nothing.  Aborting here also fails the test, but for the wrong reason -- so
'' say so on the way out.
if( o.HasValue( ) ) then
	print "FAILED: a default-constructed Optional reported HasValue( )"
	end 2
end if

'' Raises FB_RTERROR_ILLEGALFUNCTIONCALL.  With no 'on error' handler installed
'' the runtime prints 'Aborting due to runtime error 1 (illegal function call)'
'' naming the line in fb/optional.bi, and exits 1.
dim as long v = o.Value( )

'' Only reachable if the raise did not happen.
print "FAILED: Value( ) on an empty Optional returned "; v; " without raising"
end 0
