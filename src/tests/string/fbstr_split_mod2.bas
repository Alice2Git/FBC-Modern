'' A SECOND module that includes fb/string.bi.
''
'' This file has no assertions of its own. Its whole job is to be linked
'' alongside fbstr_split.bas, which includes the same header.
''
'' Split, SplitChars and Join have real FreeBASIC bodies -- they must, because
'' they return an Array( of T ), which the runtime cannot build. A body in a
'' header is emitted into every module that includes it, so without `private`
'' those bodies would collide and the link would fail with "multiple definition
'' of FB::Split". Nothing in a single-module test can catch that; only a second
'' module can.
''
'' So the assertion made here is the LINK ITSELF. If the `private` on those
'' bodies is ever dropped, this suite stops building rather than starts failing,
'' which is the louder of the two.

'' fbcunit.bi is included so the harness COLLECTS this file: unit-tests.mk
'' gathers only the .bas files that include it. There are no suites here --
'' the file exists to be compiled and linked, not to assert.
#include "fbcunit.bi"
#include once "fb/string.bi"

using FB

'' Called from fbstr_split.bas.
function SplitInOtherModule( byref s as const string ) as integer
	dim parts as Array( of string ) = Split( s, "," )

	'' use Join too, so both kinds of body are instantiated in this module
	dim as string rebuilt = Join( parts, "," )
	if rebuilt <> s then
		return -1
	end if

	return parts.Count( )
end function
