' TEST_MODE : COMPILE_AND_RUN_OK

'' The implicit destructor of a UDT whose only use is a STATIC local of a
'' PRIVATE procedure.
''
'' Private procedures are emitted at the end of the module, and only if they
'' are called.  The wrapper that destroys a static local at program exit is
'' built when its procedure is emitted, and it is the first caller of the
'' type's implicit destructor -- which is private too, and was already dropped
'' as "never called" by then: undefined reference to 'INFO::~INFO()' at link
'' time, on every backend.  Not private, or the type used anywhere else in the
'' module, and the destructor was called before the check.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

'' ------------------------------------------------------------ the report

type Info
	as string Name
	as long N
end type

private function MetaOf( ) as Info ptr
	static as Info i
	if( i.N = 0 ) then
		i.N = 1
		i.Name = "x"
	end if
	return @i
end function

assert_( MetaOf( )->Name = "x" )
assert_( MetaOf( )->N = 1 )

'' ------------------------------------------------------------ nested implicit dtors

'' Outer's implicit dtor calls Inner's: both only reached from the wrapper
type Inner
	as string s
end type

type Outer
	as Inner a
	as string t
end type

private function NestedOf( ) as Outer ptr
	static as Outer o
	o.a.s = "in"
	o.t = "out"
	return @o
end function

assert_( NestedOf( )->a.s = "in" )
assert_( NestedOf( )->t = "out" )

'' ------------------------------------------------------------ static array

type Item
	as string s
end type

private function ItemsOf( ) as Item ptr
	static as Item items( 0 to 2 )
	items( 2 ).s = "two"
	return @items( 0 )
end function

assert_( ItemsOf( )[2].s = "two" )

'' ------------------------------------------------------------ private caller chain

'' the static's procedure is itself only called from another private one
type Deep
	as string s
end type

private function DeepOf( ) as Deep ptr
	static as Deep d
	d.s = "deep"
	return @d
end function

private function CallsDeep( ) as string
	return DeepOf( )->s
end function

assert_( CallsDeep( ) = "deep" )

'' ------------------------------------------------------------ never called

'' a private procedure that is never called is still dropped, together with
'' the static's dtor wrapper; it must not keep anything from linking
type Unused
	as string s
end type

private function UnusedOf( ) as Unused ptr
	static as Unused u
	u.s = "never"
	return @u
end function
