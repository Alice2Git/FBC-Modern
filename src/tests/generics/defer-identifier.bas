' TEST_MODE : COMPILE_AND_RUN_OK

'' 'defer' as a PROCEDURE name -- backward compatibility.
''
'' Separate from defer.bas because FreeBASIC refuses a local variable that
'' shadows a module-level procedure of the same name ("error 4: Duplicated
'' definition") -- an ordinary rule with nothing to do with DEFER -- so a module
'' cannot exercise both spellings.
''
'' THE ONE KNOWN INCOMPATIBILITY the contextual keyword introduces: a PAREN-LESS
'' call in statement position, 'defer 6', now reads as a DEFER of the statement
'' '6'. 'defer( 6 )' and 'x = defer( 6 )' are unaffected, which is every call
'' that produces a value. Stated in docs/defer/defer.txt rather than hidden.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

dim shared as long deferCalls

declare function defer( byval n as long ) as long
declare sub useIt( )

	'' called with parentheses, for its value
	assert_( defer( 6 ) = 12 )
	assert_( deferCalls = 1 )

	'' in a larger expression
	assert_( defer( 2 ) + defer( 3 ) = 10 )
	assert_( deferCalls = 3 )

	'' and from inside a procedure that also uses DEFER as a keyword, so the
	'' two readings are proven to coexist in one scope
	deferCalls = 0
	useIt( )
	assert_( deferCalls = 2 )

function defer( byval n as long ) as long
	deferCalls += 1
	return n * 2
end function

sub useIt( )
	dim as long total = 0

	'' keyword reading: next token begins a statement
	defer total += defer( 5 )

	'' call reading: next token is '('
	total = defer( 1 )
	assert_( total = 2 )
end sub
