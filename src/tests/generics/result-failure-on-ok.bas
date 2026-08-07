' TEST_MODE : COMPILE_AND_RUN_FAIL

'' FB.Result( of T, E ).Failure( ) on a SUCCESSFUL Result must raise.
''
'' The mirror of result-value-on-failure.bas.  Both directions are pinned
'' because the symmetry is a deliberate design decision, not an accident of the
'' implementation: asking why something failed when it did not fail is the same
'' class of mistake as reading a value that is not there, and it is the one a
'' one-sided implementation would let through silently.

#include once "fb/result.bi"
using FB

dim r as Result( of long, string ) = Ok( of long, string )( 7L )

'' Guard: if this were somehow a failure, the file would be testing nothing.
if( r.IsOk( ) = FALSE ) then
	print "FAILED: an Ok( )-constructed Result did not report IsOk( )"
	end 2
end if

'' The value side is readable, and does not raise.
if( r.Value( ) <> 7 ) then
	print "FAILED: Value( ) returned "; r.Value( )
	end 2
end if

'' Raises FB_RTERROR_ILLEGALFUNCTIONCALL: exits 1 naming the line in
'' fb/result.bi.
dim as string f = r.Failure( )

print "FAILED: Failure( ) on a successful Result returned '" & f & "' without raising"
end 0
