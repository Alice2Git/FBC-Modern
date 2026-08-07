'' DEFER's own diagnostics.
''
'' 'defer' is a CONTEXTUAL keyword, so most mistakes involving it are not defer
'' errors at all -- they are whatever the identifier reading produces. Only the
'' cases below are DEFER's to report.

#print === DEFER with no statement ===
sub noStatement( )
	defer
end sub

#print === DEFER at module level ===
defer print "nothing would ever run this"

#print === branch crossing a DEFER ===
'' Cleanup is derived from the symbol table, so jumping PAST a defer does not
'' skip it -- the statement still runs at the scope's exits. Refused rather
'' than left to surprise someone, exactly as crossing a ctor'd local is.
sub crossing( )
	scope
		goto skip
		defer print "still runs"
		skip:
	end scope
end sub
