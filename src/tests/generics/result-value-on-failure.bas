' TEST_MODE : COMPILE_AND_RUN_FAIL

'' FB.Result( of T, E ).Value( ) on a FAILED Result must raise.
''
'' Separate module because the raise aborts the process.  COMPILE_AND_RUN_FAIL
'' means the harness requires a clean compile and a NON-ZERO exit code, so the
'' real assertion is "control never reaches the end".

#include once "fb/result.bi"
using FB

dim r as Result( of long, string ) = Fail( of long, string )( "no such thing" )

'' Guard: if this were somehow Ok, the file would be testing nothing.
if( r.IsOk( ) ) then
	print "FAILED: a Fail( )-constructed Result reported IsOk( )"
	end 2
end if

'' The failure side is readable, and does not raise.
if( r.Failure( ) <> "no such thing" ) then
	print "FAILED: Failure( ) returned '" & r.Failure( ) & "'"
	end 2
end if

'' Raises FB_RTERROR_ILLEGALFUNCTIONCALL: exits 1 naming the line in
'' fb/result.bi.
dim as long v = r.Value( )

print "FAILED: Value( ) on a failed Result returned "; v; " without raising"
end 0
