'' fb/optional.bi -- FB.Optional( of T ), a value that might not be there
''
'' Sketch S.2.  Replaces the "encode absence in the value" idiom, which is
'' spelled differently in every library and is indistinguishable from a
'' legitimate result whenever the sentinel is itself a legal value:
''
''     function Find( ... ) as long        '' don't -- is -1 "absent" or an index?
''     if( Find( ... ) = -1 ) then
''
''     function Find( ... ) as Optional( of long )     '' do
''     if( r.HasValue( ) ) then
''
'' It also removes the out-parameter form -- 'TryGet( key, byref out )' exists
'' only because there was no way to return "a long, or nothing".
''
'' LIBRARY ONLY.  No compiler change, and deliberately no sum type underneath:
'' this is a T plus a flag, not a tagged union.  There is no '?' operator, no
'' must-use diagnostic, and ignoring an Optional stays a convention rather than
'' an error.  What it buys is that the absence is IN THE TYPE and has a name.
''
'' NO MEMBER MAY CONSTRAIN T.  Every member body of a generic is replayed for
'' every instantiation whether or not it is ever called -- there is no lazy
'' member instantiation.  A member needing '=' on T would make the whole type
'' unusable for any T without one, exactly as Array's IndexOf/Sort had to become
'' free procedures.  So Optional's members use only default construction, copy
'' and destruction, and there is intentionally no operator '=', no comparison
'' and no ToString.  Anything needing more is a free procedure.
''
'' A DEFAULT-CONSTRUCTED OPTIONAL IS EMPTY.  'dim o as Optional( of long )' has
'' no value; there is no separate "uninitialised" state to get wrong.  The
'' stored T is still default-constructed, because a field must be -- so an
'' Optional( of T ) costs a T plus a boolean whether or not it is engaged, and
'' T's default constructor runs.  That is the price of not using a union.
''
'' EMPTY ACCESS RAISES.  Value( ) on an empty Optional raises the runtime error
'' FB_RTERROR_ILLEGALFUNCTIONCALL through the ordinary fbc path, so it is
'' catchable by 'on error' and reports a line under -exx.  With no handler
'' installed the program aborts with 'runtime error 1 (illegal function call)'
'' and the line inside this file, which is the intended outcome: reading a value
'' that is not there is a bug at the call site, not a recoverable condition.
'' It still has to return a reference to something afterwards; it returns the
'' stored slot, which is always a real default-constructed T.  ValueOr( ) is the
'' branch-free alternative and never raises.
''
'' NOT ITERABLE.  No GetIterator( ), so 'for each' over an Optional is a
'' compile error rather than a zero-or-one loop.  A maybe-value is not a
'' sequence, and pretending it is makes the absence easy to skip silently.

#pragma once

'' For FB_RTERROR_ILLEGALFUNCTIONCALL.  fberror.bi is a 37-line enum which
'' already declares itself inside 'namespace FB' under -lang fb, so this costs
'' nothing and names the error rather than spelling a bare number.
#include once "fberror.bi"

namespace FB

type Optional( of T )
	as T v
	as boolean has

	declare function HasValue( ) as boolean
	declare function Value( ) byref as T
	declare function ValueOr( byref dflt as T ) byref as T
	declare sub Clear( )
end type

function Optional( of T ).HasValue( ) as boolean
	return this.has
end function

'' Raises 'illegal function call' when empty.  The 'return this.v' after it is
'' not dead code: 'error' does not terminate the procedure -- with an 'on error'
'' handler installed, control comes back here -- and a BYREF return must refer
'' to something.
''
'' It refers to the stored slot, NOT to a function-static blank.  LinkedList's
'' Front( ) needs a static because an empty list has no node to point at; an
'' Optional always has its field, default-constructed, so there is a real object
'' here already.  Using a static instead would be a leak with a measured cause:
'' a function-'static' UDT in FreeBASIC is constructed lazily on first call and
'' is NEVER destroyed, so every instantiation of this member would retain one T
'' -- and its resources -- for the lifetime of the program.
function Optional( of T ).Value( ) byref as T
	if( this.has = FALSE ) then
		error( FB_RTERROR_ILLEGALFUNCTIONCALL )
	end if
	return this.v
end function

'' Never raises.  Returns BYREF, so the result aliases either the stored value
'' or the caller's default -- passing a temporary as dflt gives a reference that
'' dies at the end of the statement, the same hazard as any byref return.
function Optional( of T ).ValueOr( byref dflt as T ) byref as T
	if( this.has = FALSE ) then
		return dflt
	end if
	return this.v
end function

'' Drops the value and becomes empty.  The slot is reset so that a T holding a
'' resource -- a string, a container -- releases it now rather than when the
'' Optional itself dies.
sub Optional( of T ).Clear( )
	dim as T blank
	this.v = blank
	this.has = FALSE
end sub

'' ------------------------------------------------- free generic procedures
''
'' Construction is a free procedure rather than a constructor because T is then
'' inferred from the argument -- 'Some( 3 )' rather than
'' 'Optional( of integer )( 3 )'.
''
'' INFERENCE READS PARAMETER POSITIONS ONLY.  'Some( 3 )' binds T to INTEGER,
'' not to LONG, because that is the type of the literal.  Assigning the result
'' to an Optional( of long ) is a type mismatch, not a conversion.  Write
'' 'Some( 3L )', exactly as IndexOf( nums, 3L ) already has to be written.
function Some( of T )( byref v as T ) as Optional( of T )
	dim as Optional( of T ) r
	r.v = v
	r.has = TRUE
	return r
end function

'' The empty Optional, for a 'return None( of long )( )' that reads as a
'' decision rather than as a forgotten assignment.  T cannot be inferred here --
'' there is no argument to infer it from -- so it must be written out.
function None( of T )( ) as Optional( of T )
	dim as Optional( of T ) r
	return r
end function

end namespace
