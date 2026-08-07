' TEST_MODE : COMPILE_ONLY_FAIL

'' Result stores BOTH a T and an E by value, so BOTH must be
'' default-constructible -- a default-constructed Result is a failure, and its
'' value slot is still a real object that has to be built.
''
'' This is a stricter requirement than Optional's, and it is the visible cost of
'' having no sum types: a tagged union would construct only the active slot.
''
'' Here the offender is in the E position, which is the half a test that only
'' exercised T would miss.

#include once "fb/result.bi"
using FB

type NoDefaultCtor
	as long a
	declare constructor( byval n as long )
end type

constructor NoDefaultCtor( byval n as long )
	this.a = n
end constructor

dim r as Result( of long, NoDefaultCtor )
print r.IsOk( )
