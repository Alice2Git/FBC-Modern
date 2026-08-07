' TEST_MODE : COMPILE_ONLY_FAIL

'' Optional stores its T by value, so T must be default-constructible: a
'' default-constructed Optional is empty, and its slot is still a real object.
''
'' Declaring any constructor suppresses FreeBASIC's implicit default one, so
'' this T has none and 'as T v' cannot be laid out.  Refusing it here rather
'' than at some later use is the point of pinning it.
''
'' The alternative -- a union or raw storage, so the slot is only constructed
'' when engaged -- was not taken: see the header comment in fb/optional.bi.

#include once "fb/optional.bi"
using FB

type NoDefaultCtor
	as long a
	declare constructor( byval n as long )
end type

constructor NoDefaultCtor( byval n as long )
	this.a = n
end constructor

dim o as Optional( of NoDefaultCtor )
print o.HasValue( )
