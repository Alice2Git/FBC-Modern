' TEST_MODE : COMPILE_ONLY_OK

'' END's exit code may start with a keyword that is a built-in function.
''
'' Every 'END <keyword>' was parsed as the end of a block, so 'end iif( ... )',
'' 'end len( s )' and 'end cint( x )' failed with error 33, Illegal 'END'.  A
'' block-ending keyword is never followed by '(', so a keyword followed by '('
'' is the start of the exit code expression.  Each END below is only compiled,
'' never reached.

dim as long x = 3
dim as string s = "abc"

if x = 0 then
	end iif( x = 3, 7, 1 )
end if
if x = 0 then
	end len( s )
end if
if x = 0 then
	end cint( 2.6 )
end if
if x = 0 then
	end abs( -4 )
end if
if x = 0 then
	end sizeof( x )
end if

'' unchanged: the ordinary forms
if x = 0 then
	end ( iif( x = 3, 7, 1 ) )
end if
if x = 0 then
	end x + 1
end if
if x = 0 then
	end
end if
