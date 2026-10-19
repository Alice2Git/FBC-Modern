' TEST_MODE : COMPILE_AND_RUN_OK

'' A STRING * 8 initialised next to another variable.
''
'' A new STRING * 8 is filled with 8 spaces.  -gen gas64 wrote them as two
'' DWORD stores through a register holding its address:
''
''     lea r11, -112[rbp]
''     mov DWORD PTR [r11], 0x20202020
''     mov DWORD PTR 4[r11], 0x20202020
''
'' The peephole optimizer merged the LEA into the first store and dropped it,
'' so the second store went through whatever the register held before -- most
'' often the address of the variable initialised just before.  A STRING there
'' had 4 spaces written into its data pointer: the program crashed, or the
'' STRING lost its value.  Only the size 8 took this path.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type TStr
	as string txt
end type

type TFix
	as string * 8 f
end type

type TBoth
	as string txt
	as string * 8 f
	as string * 8 g
end type

sub InSub( )
	dim as string s
	dim as string * 8 f
	s = "sub"
	assert_( s = "sub" )
	assert_( f = space( 8 ) )
	f = "ab"
	assert_( f = "ab      " )
	assert_( s = "sub" )
end sub

sub UdtInSub( )
	dim as TStr x
	dim as TFix y
	x.txt = "txt"
	assert_( x.txt = "txt" )
	assert_( y.f = space( 8 ) )
end sub

'' module level
dim as string s
dim as string * 8 f
s = "abc"
assert_( s = "abc" )
assert_( f = space( 8 ) )
assert_( len( f ) = 8 )

'' a STRING field followed by STRING * 8 fields
dim as TBoth b
b.txt = "txt"
assert_( b.txt = "txt" )
assert_( b.f = space( 8 ) )
assert_( b.g = space( 8 ) )
b.f = "12345678"
assert_( b.f = "12345678" )
assert_( b.g = space( 8 ) )
assert_( b.txt = "txt" )

'' separate UDT variables
dim as TStr x
dim as TFix y
x.txt = "txt"
assert_( x.txt = "txt" )
assert_( y.f = space( 8 ) )

'' an integer just before: its value must survive
dim as longint n = &h1122334455667788
dim as longint ptr pn = @n
dim as string * 8 f2
assert_( n = &h1122334455667788 )
assert_( *pn = &h1122334455667788 )
assert_( f2 = space( 8 ) )

InSub( )
UdtInSub( )
