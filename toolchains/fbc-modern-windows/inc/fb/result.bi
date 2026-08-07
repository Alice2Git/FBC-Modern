'' fb/result.bi -- FB.Result( of T, E ), a value or the reason there isn't one
''
'' Sketch S.5.  Replaces the global-status-code idiom, in which the error is not
'' part of the return type, does not participate in the type system, and is
'' trivially ignored:
''
''     dim v as long = Parse( s )       '' don't -- did it work?  ask err, maybe
''     if( err <> 0 ) then
''
''     dim r as Result( of long, string ) = Parse( s )      '' do
''     if( r.IsOk( ) ) then ... else print r.Failure( )
''
'' The difference from Optional is the E: Optional says "nothing is here",
'' Result says "nothing is here, AND this is why".  Use Optional when absence
'' needs no explanation -- a lookup that missed -- and Result when it does.
''
'' LIBRARY ONLY.  No compiler change, and deliberately no sum type underneath:
'' this is a T and an E and a flag, not a tagged union.  There is no '?'
'' operator and no must-use diagnostic, so IGNORING A RESULT STAYS A CONVENTION
'' rather than an error.  That is the honest limit of a library-only version:
'' what it buys is that the failure has a type and a name, not that you are
'' forced to look at it.
''
'' A DEFAULT-CONSTRUCTED RESULT IS A FAILURE.  'dim r as Result( of long,
'' string )' is failed, carrying a default-constructed E.  There is no third
'' state, and the choice of which of the two states to default to is not
'' arbitrary: a Result that nobody has set must not read as success, or every
'' forgotten assignment becomes a silent Ok.
''
'' BOTH SLOTS ALWAYS EXIST.  A Result is a T plus an E plus a boolean, so both
'' default constructors run and the size is the sum, not the maximum.  That is
'' the price of not having sum types in the language, and it means BOTH T and E
'' must be default-constructible.
''
'' NO MEMBER MAY CONSTRAIN T OR E.  Every member body of a generic is replayed
'' for every instantiation whether or not it is ever called -- there is no lazy
'' member instantiation.  A member needing '=' would make the whole type
'' unusable for a T or an E without one, exactly as Array's IndexOf/Sort had to
'' become free procedures.  So the members here use only default construction,
'' copy and destruction, and there is intentionally no operator '=', no
'' comparison and no ToString.
''
'' READING THE WRONG SIDE RAISES.  Value( ) on a failed Result and Failure( ) on
'' a successful one both raise FB_RTERROR_ILLEGALFUNCTIONCALL, symmetrically.
'' IsOk( ) is the guard, and it costs nothing.
''
'' T AND E MAY BE THE SAME TYPE.  Result( of string, string ) is legal and is a
'' normal thing to want -- a parsed word or a message saying why not.  The two
'' slots stay distinct because they are separate fields, not a union.

#pragma once

'' For FB_RTERROR_ILLEGALFUNCTIONCALL.  fberror.bi is a 37-line enum which
'' already declares itself inside 'namespace FB' under -lang fb.
#include once "fberror.bi"

namespace FB

type Result( of T, E )
	'' The failure slot is named 'f', not the obvious 'e'.  FreeBASIC
	'' identifiers are case-insensitive, so a field 'e' IS the type parameter
	'' 'E', and the instantiation fails with a misleading
	'' 'error 14: Expected identifier, found E'.
	as T v
	as E f
	as boolean ok

	declare function IsOk( ) as boolean
	declare function Value( ) byref as T
	declare function Failure( ) byref as E
	declare function ValueOr( byref dflt as T ) byref as T
end type

function Result( of T, E ).IsOk( ) as boolean
	return this.ok
end function

'' Raises when the Result is a failure.  The 'return this.v' after it is not
'' dead code: 'error' does not terminate the procedure -- with an 'on error'
'' handler installed, control comes back here -- and a BYREF return must refer
'' to something.
''
'' It refers to the stored slot, which is always a real default-constructed T,
'' and NOT to a function-'static' blank: such a static is constructed lazily on
'' first call and is never destroyed, so it would retain one T per instantiation
'' for the lifetime of the program.
function Result( of T, E ).Value( ) byref as T
	if( this.ok = FALSE ) then
		error( FB_RTERROR_ILLEGALFUNCTIONCALL )
	end if
	return this.v
end function

'' The mirror of Value( ), and it raises on the mirrored condition: asking why
'' something failed when it did not fail is the same class of mistake as reading
'' a value that is not there.
function Result( of T, E ).Failure( ) byref as E
	if( this.ok ) then
		error( FB_RTERROR_ILLEGALFUNCTIONCALL )
	end if
	return this.f
end function

'' Never raises.  Returns BYREF, so the result aliases either the stored value
'' or the caller's default -- passing a temporary as dflt gives a reference that
'' dies at the end of the statement, the same hazard as any byref return.
''
'' There is no matching FailureOr( ): a default reason for a success is not a
'' thing anyone wants.
function Result( of T, E ).ValueOr( byref dflt as T ) byref as T
	if( this.ok = FALSE ) then
		return dflt
	end if
	return this.v
end function

'' ------------------------------------------------- free generic procedures
''
'' Construction is by free procedure rather than by constructor so that the two
'' states have names at the point they are produced -- 'return Fail( ... )'
'' rather than a two-line assignment whose meaning depends on a flag.
''
'' BOTH TYPE ARGUMENTS MUST BE WRITTEN OUT.  Inference reads parameter positions
'' only, and each of these mentions just one of T and E in its parameters, so
'' neither can be inferred whole:
''
''     return Ok( of long, string )( 3L )
''     return Fail( of long, string )( "not a number" )
''
'' That is more ceremony than Optional's Some( x ), and it is the reason the
'' return type is usually spelled once in a typedef:
''
''     type ParseResult as Result( of long, string )
function Ok( of T, E )( byref v as T ) as Result( of T, E )
	dim as Result( of T, E ) r
	r.v = v
	r.ok = TRUE
	return r
end function

function Fail( of T, E )( byref f as E ) as Result( of T, E )
	dim as Result( of T, E ) r
	r.f = f
	r.ok = FALSE
	return r
end function

end namespace
