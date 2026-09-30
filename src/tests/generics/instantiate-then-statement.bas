' TEST_MODE : COMPILE_AND_RUN_OK

'' The statement right after a generic's first instantiation.
''
'' Member bodies are replayed at the next module-level statement boundary --
'' by which point the lexer has already read that statement's first token,
'' and looked its symbol up.  A lookup result is a chain in a ring buffer of
'' 4096 entries, and replaying these bodies performs several times that many
'' lookups, so the ring wrapped and the token's chain was overwritten with
'' whatever the replay had looked up last.  The statement after 'dim m as
'' Big( of long )' was then parsed against some unrelated symbol:
''
''     error 215: Only static members can be accessed from static functions
''                and parameter initializers, found 'Show'
''
'' -- or error 42, 58, 202 or 214, depending on what the ring held.  A
'' statement starting with DIM happened to survive, because DIM's parser
'' never reads the chain, which is why a 'warm-up' dim was the workaround.
''
'' Each replay now allocates from a ring of its own.  Big( of T ) exists only
'' to be large: its bodies must perform well over 4096 lookups, or this test
'' cannot see the bug.  Forty such bodies are about three times the threshold.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Big( of T )
	as T v
	declare function M00( byval k as T ) as T
	declare function M01( byval k as T ) as T
	declare function M02( byval k as T ) as T
	declare function M03( byval k as T ) as T
	declare function M04( byval k as T ) as T
	declare function M05( byval k as T ) as T
	declare function M06( byval k as T ) as T
	declare function M07( byval k as T ) as T
	declare function M08( byval k as T ) as T
	declare function M09( byval k as T ) as T
	declare function M10( byval k as T ) as T
	declare function M11( byval k as T ) as T
	declare function M12( byval k as T ) as T
	declare function M13( byval k as T ) as T
	declare function M14( byval k as T ) as T
	declare function M15( byval k as T ) as T
	declare function M16( byval k as T ) as T
	declare function M17( byval k as T ) as T
	declare function M18( byval k as T ) as T
	declare function M19( byval k as T ) as T
	declare function M20( byval k as T ) as T
	declare function M21( byval k as T ) as T
	declare function M22( byval k as T ) as T
	declare function M23( byval k as T ) as T
	declare function M24( byval k as T ) as T
	declare function M25( byval k as T ) as T
	declare function M26( byval k as T ) as T
	declare function M27( byval k as T ) as T
	declare function M28( byval k as T ) as T
	declare function M29( byval k as T ) as T
	declare function M30( byval k as T ) as T
	declare function M31( byval k as T ) as T
	declare function M32( byval k as T ) as T
	declare function M33( byval k as T ) as T
	declare function M34( byval k as T ) as T
	declare function M35( byval k as T ) as T
	declare function M36( byval k as T ) as T
	declare function M37( byval k as T ) as T
	declare function M38( byval k as T ) as T
	declare function M39( byval k as T ) as T
	declare function IsEmpty( ) as boolean
end type

function Big( of T ).M00( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M01( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M02( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M03( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M04( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M05( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M06( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M07( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M08( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M09( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M10( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M11( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M12( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M13( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M14( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M15( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M16( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M17( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M18( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M19( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M20( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M21( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M22( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M23( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M24( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M25( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M26( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M27( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M28( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M29( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M30( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M31( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M32( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M33( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M34( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M35( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M36( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M37( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M38( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).M39( byval k as T ) as T
	dim as T a = this.v, b = k, c = a
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k : a = a + b : b = b + c : c = c + a : a = this.v + k
	return a + b + c
end function

function Big( of T ).IsEmpty( ) as boolean
	return this.v = 0
end function

dim shared as long shown

sub Show( byval b as boolean )
	if( b ) then shown += 1
end sub

'' an identifier statement right after the instantiation: a call whose
'' argument uses the new type
dim as Big( of long ) m
Show( m.IsEmpty( ) )
assert_( shown = 1 )

'' a keyword statement: keywords are looked up through the same ring
dim as Big( of double ) d
print ;
Show( d.IsEmpty( ) )
assert_( shown = 2 )

'' and the members themselves work
m.v = 1
assert_( m.IsEmpty( ) = false )
assert_( m.M00( 2 ) <> 0 )
assert_( d.M39( 1.5 ) <> 0 )
