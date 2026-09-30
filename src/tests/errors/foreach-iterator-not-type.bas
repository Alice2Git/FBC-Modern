'' FOR EACH over a type whose GetIterator( ) exists but does not return an
'' iterator TYPE -- here a pointer, inherited from a generic base.
''
'' This used to report "Type is not iterable ... __FBGENINST": as if
'' GetIterator were missing, and naming the instantiation by its internal name.
'' One case per file (see readme.txt).

#print === GetIterator returns a pointer ===
type Baza( of T )
	as T v( 0 to 2 )
	declare function GetIterator( ) as T ptr
end type
function Baza( of T ).GetIterator( ) as T ptr
	return @this.v( 0 )
end function
type Derivat( of T ) extends Baza( of T )
end type

dim d as Derivat( of long )

for each x as long in d
next
