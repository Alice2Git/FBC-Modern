'' USTRING used every way the language allows.
''
'' This is a SHOWCASE and a TEST at the same time. Every construct below is
'' checked, not just compiled, so it doubles as documentation you can trust:
'' if a form is in this file, it works, and the expected value is stated next
'' to it.
''
'' Covered: every declaration form, dynamic and fixed, arrays (static, dynamic,
'' multi-dimensional, initialised), UDTs, inheritance and virtual methods,
'' properties, operator overloads, every parameter mode (BYVAL / BYREF /
'' BYREF AS CONST, dynamic and fixed), pointers, and every return form
'' (BYVAL, BYREF, fixed-length).
''
'' NOT covered, because it is not supported: CONST u AS USTRING = "...".
'' fbc's CONST accepts only FB_DATATYPE_STRING -- WSTRING is rejected too. See
'' the "Known gap" section of README.md. Everything else here works.

'' The astral character used throughout. Change ASTRAL_CP alone -- every
'' surrogate assertion below is DERIVED from it, so the two cannot drift apart.
''   &h1D11E  |𝄞|  MUSICAL SYMBOL G CLEF   surrogates D834 DD1E
''   &h1F989  |🦉| OWL                     surrogates D83E DD89
#define ASTRAL_CP &h1F989
#define ASTRAL    wchr(ASTRAL_CP)          '' one character, TWO code units

#define ASTRAL_HI (&hD800 + ((ASTRAL_CP - &h10000) shr 10))
#define ASTRAL_LO (&hDC00 + ((ASTRAL_CP - &h10000) and &h3FF))

dim shared as integer g_run, g_fail

declare function total_len( u() as ustring ) as integer

sub chk( byref nm as string, byval got as longint, byval want as longint )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        print "FAIL "; nm; " got="; got; " want="; want
    end if
end sub

sub chks( byref nm as string, byref got as ustring, byref want as ustring )
    g_run += 1
    if( got <> want ) then
        g_fail += 1
        dim as string a = got, b = want
        print "FAIL "; nm; " got=["; a; "] want=["; b; "]"
    end if
end sub


'' =====================================================================
''  1. DECLARATION FORMS
'' =====================================================================

'' -- module-level SHARED, and COMMON SHARED
dim shared as ustring g_dyn
dim shared as ustring * 32 g_fix
common shared as ustring g_common

'' -- a type alias works like any other type name
type ustr_t as ustring
type ufix_t as ustring * 12

sub decl_forms( )
    '' the two orderings, with and without an initialiser
    dim as ustring a
    dim as ustring b = "beta"
    dim c as ustring
    dim d as ustring = "delta"

    '' several in one statement, mixed initialisation
    dim as ustring e, f = "phi", g

    a = "alpha" : c = "gamma" : e = "epsilon" : g = "omega"

    chks( "dim as ustring a",          a, "alpha" )
    chks( "dim as ustring b = ...",    b, "beta" )
    chks( "dim c as ustring",          c, "gamma" )
    chks( "dim d as ustring = ...",    d, "delta" )
    chks( "multiple in one dim",       e + f + g, "epsilonphiomega" )

    '' fixed length -- N is CODE UNITS, not bytes
    dim as ustring * 16 h = "fixed"
    dim i as ustring * 8 = "eight"
    chks( "dim as ustring * 16",       h, "fixed" )
    chks( "dim i as ustring * 8",      i, "eight" )
    chk ( "LEN of fixed is text len",  len(h), 5 )
    chk ( "SIZEOF ustring * 16",       sizeof(h), 32 )      '' 16 units x 2 bytes

    '' VAR infers the DYNAMIC form, even from a fixed source
    var v1 = b + "!"
    var v2 = h                        '' from a USTRING * 16 -> dynamic
    chks( "VAR from expression",       v1, "beta!" )
    chks( "VAR from fixed",            v2, "fixed" )
    v2 += " grows"                    '' proves it really is dynamic
    chks( "VAR result is dynamic",     v2, "fixed grows" )

    '' type aliases
    dim as ustr_t t1 = "aliased"
    dim as ufix_t t2 = "alias12"
    chks( "TYPE alias, dynamic",       t1, "aliased" )
    chks( "TYPE alias, fixed",         t2, "alias12" )

    '' STATIC keeps its value across calls
    static as ustring s_acc
    s_acc += "x"

    '' shared / common
    g_dyn = "shared"
    g_fix = "sharedfix"
    g_common = "common"
    chks( "DIM SHARED",                g_dyn, "shared" )
    chks( "DIM SHARED fixed",          g_fix, "sharedfix" )
    chks( "COMMON SHARED",             g_common, "common" )

    '' pointers
    dim as ustring ptr p = @b
    chks( "USTRING PTR deref",         *p, "beta" )
    *p += "!!"
    chks( "write through the pointer",  b, "beta!!" )
    chk ( "VARPTR is non-null",        cint( varptr(b) <> 0 ), -1 )

    '' STRPTR gives the raw UTF-16 units
    dim as ustring uni = wchr(&h20AC) & "A"
    dim as ushort ptr up = strptr(uni)      '' USHORT PTR, no cast needed
    chk ( "STRPTR unit 0 (euro)",      up[0], &h20AC )
    chk ( "STRPTR unit 1 (A)",         up[1], asc("A") )
end sub

'' STATIC across two calls
sub static_counter( byref out_len as integer )
    static as ustring acc
    acc += "ab"
    out_len = len(acc)
end sub


'' =====================================================================
''  2. ARRAYS
'' =====================================================================

sub arrays( )
    '' fixed-size array of dynamic ustrings
    dim as ustring a(0 to 3)
    for i as integer = 0 to 3
        a(i) = "item" & i
    next
    chks( "array of dynamic",          a(2), "item2" )

    '' array with an initialiser
    dim as ustring b(0 to 2) = { "one", "two", "three" }
    chks( "array initialiser",         b(0) + b(1) + b(2), "onetwothree" )

    '' array of FIXED-length ustrings
    dim as ustring * 8 c(0 to 2)
    c(0) = "aa" : c(1) = "bb" : c(2) = "cc"
    chks( "array of fixed",            c(0) + c(1) + c(2), "aabbcc" )

    '' multi-dimensional
    dim as ustring d(0 to 1, 0 to 1)
    d(0,0) = "00" : d(0,1) = "01" : d(1,0) = "10" : d(1,1) = "11"
    chks( "2-D array",                 d(1,0), "10" )

    '' dynamic array, grown with REDIM PRESERVE
    redim as ustring e(0 to 1)
    e(0) = "keep" : e(1) = "me"
    redim preserve e(0 to 4)
    e(4) = "added"
    chks( "REDIM PRESERVE keeps [0]",  e(0), "keep" )
    chks( "REDIM PRESERVE keeps [1]",  e(1), "me" )
    chks( "REDIM PRESERVE new slot",   e(4), "added" )
    chk ( "UBOUND after REDIM",        ubound(e), 4 )

    '' ERASE frees the contents
    erase e
    chk ( "ERASE empties the array",   len(e(0)), 0 )

    '' array passed to a procedure by descriptor
    chk ( "array BYDESC total length", total_len( a() ), 5*4 )
end sub

'' arrays are passed by descriptor
function total_len( u() as ustring ) as integer
    dim as integer n
    for i as integer = lbound(u) to ubound(u)
        n += len( u(i) )
    next
    return n
end function


'' =====================================================================
''  3. USER-DEFINED TYPES
'' =====================================================================

type Simple
    as ustring      dyn            '' dynamic field
    as ustring * 8  fix            '' fixed field
    as ustring      arr(0 to 2)    '' array field
end type

type Inner
    as ustring tag
end type

type Outer
    as Inner   inner_
    as ustring name
end type

union UBox
    as ustring * 4 text            '' fixed only: a union member cannot be
    as ushort      units(0 to 3)   '' a var-len descriptor
end union

'' A type with a constructor, destructor, property and operators
type Box
    public:
        declare constructor( )
        declare constructor( byref s as ustring )
        declare destructor( )
        declare property value( ) as ustring
        declare property value( byref s as ustring )
        declare operator let( byref s as ustring )
        declare operator cast( ) as ustring
        declare function shout( ) as ustring
    private:
        as ustring m_v
end type

constructor Box( )
    m_v = "(empty)"
end constructor

constructor Box( byref s as ustring )
    m_v = s
end constructor

destructor Box( )
    '' m_v is destroyed by the generated field destructor
end destructor

property Box.value( ) as ustring
    return m_v
end property

property Box.value( byref s as ustring )
    m_v = s
end property

operator Box.let( byref s as ustring )
    m_v = s
end operator

operator Box.cast( ) as ustring
    return m_v
end operator

function Box.shout( ) as ustring
    return ucase( m_v ) & "!"
end function

'' a free operator taking a ustring
operator + ( byref b as Box, byref s as ustring ) as ustring
    return b.value & s
end operator

sub udts( )
    dim as Simple s
    s.dyn = "dynamic field"
    s.fix = "fixed"
    s.arr(1) = "in an array field"
    chks( "UDT dynamic field",         s.dyn, "dynamic field" )
    chks( "UDT fixed field",           s.fix, "fixed" )
    chks( "UDT array field",           s.arr(1), "in an array field" )

    dim as Outer o
    o.inner_.tag = "nested"
    o.name = "outer"
    chks( "nested UDT field",          o.inner_.tag, "nested" )

    '' WITH
    with o
        .name = "with-assigned"
    end with
    chks( "WITH block",                o.name, "with-assigned" )

    dim as UBox ub
    ub.text = "AB"
    chk ( "UNION fixed member unit 0", ub.units(0), asc("A") )
    chk ( "UNION fixed member unit 1", ub.units(1), asc("B") )

    '' constructors
    dim as Box b1
    dim as Box b2 = Box( "made" )
    chks( "default constructor",       b1.value, "(empty)" )
    chks( "constructor with ustring",  b2.value, "made" )

    '' property get/set
    b1.value = "via property"
    chks( "property set/get",          b1.value, "via property" )

    '' OPERATOR LET
    b1 = "via LET"
    chks( "OPERATOR LET",              b1.value, "via LET" )

    '' OPERATOR CAST to ustring
    dim as ustring casted = b1
    chks( "OPERATOR CAST",             casted, "via LET" )

    '' a method returning a ustring
    chks( "method returns ustring",    b2.shout(), "MADE!" )

    '' a free operator
    chks( "free operator +",           b2 + " it", "made it" )

    '' array of UDTs, each with ustring fields
    dim as Box boxes(0 to 2)
    for i as integer = 0 to 2
        boxes(i).value = "box" & i
    next
    chks( "array of UDTs",             boxes(2).value, "box2" )
end sub


'' =====================================================================
''  4. "CLASSES" -- FB spells them TYPE ... EXTENDS
'' =====================================================================

type Animal extends Object
    declare constructor( )
    declare constructor( byref nm as ustring )
    declare virtual function speak( ) as ustring
    declare virtual destructor( )
    as ustring name
end type

constructor Animal( )
    name = "(unnamed)"
end constructor

constructor Animal( byref nm as ustring )
    name = nm
end constructor

virtual destructor Animal( )
end destructor

virtual function Animal.speak( ) as ustring
    return name & " makes a sound"
end function

type Dog extends Animal
    declare constructor( byref nm as ustring )
    declare function speak( ) as ustring override
end type

constructor Dog( byref nm as ustring )
    base( nm )
end constructor

function Dog.speak( ) as ustring
    return name & " says wöff"
end function

sub classes( )
    dim as Animal a = Animal( "Generic" )
    chks( "base virtual method",       a.speak(), "Generic makes a sound" )

    dim as Dog d = Dog( "Rex" )
    chks( "derived override",          d.speak(), "Rex says w" & wchr(&hF6) & "ff" )

    '' called through a base pointer -- the vtable dispatch returns a ustring
    dim as Animal ptr p = @d
    chks( "virtual via base ptr",      p->speak(), "Rex says w" & wchr(&hF6) & "ff" )

    '' NEW / DELETE
    dim as Dog ptr heap_ = new Dog( "Heap" )
    chks( "NEW'd object",              heap_->speak(), "Heap says w" & wchr(&hF6) & "ff" )
    delete heap_
end sub


'' =====================================================================
''  5. PARAMETER PASSING
'' =====================================================================

'' BYVAL -- the callee gets a copy, the caller is untouched
sub p_byval( byval u as ustring )
    u += " MODIFIED"
end sub

'' BYREF -- the callee writes through to the caller
sub p_byref( byref u as ustring )
    u += " MODIFIED"
end sub

'' BYREF AS CONST -- read-only, and takes literals and temporaries too
function p_byref_const( byref u as const ustring ) as integer
    return len( u )
end function

'' BYVAL AS CONST
function p_byval_const( byval u as const ustring ) as integer
    return len( u )
end function

'' fixed-length argument bound to a dynamic parameter
function p_from_fixed( byref u as const ustring ) as ustring
    return ucase( u )
end function

'' NOTE: "byref f as ustring * 8" does not compile -- FB rejects a
'' fixed-length string combined with BYREF for EVERY string type:
''
''   error 324: Fixed-length string combined with BYREF (not supported)
''
'' It is identical for STRING * N, ZSTRING * N and WSTRING * N, so this is a
'' general FB rule and not a USTRING limitation. Take a dynamic parameter; a
'' fixed-length argument binds to it, and writing back through it works.
sub p_fixed( byref f as ustring )
    f = "setfix"
end sub

'' pointer parameter
sub p_ptr( byval p as ustring ptr )
    *p += " viaptr"
end sub

'' optional parameter with a default
function p_optional( byref u as const ustring = "defaulted" ) as ustring
    return u
end function

'' overloads that differ only in string type -- resolution must pick right
function which_ovl overload ( byref u as const ustring ) as string
    return "ustring"
end function
function which_ovl overload ( byref s as const string ) as string
    return "string"
end function
function which_ovl overload ( byval w as const wstring ptr ) as string
    return "wstring"
end function

sub params( )
    dim as ustring u = "orig"

    p_byval( u )
    chks( "BYVAL does not modify",     u, "orig" )

    p_byref( u )
    chks( "BYREF modifies",            u, "orig MODIFIED" )

    chk ( "BYREF AS CONST",            p_byref_const( u ), 13 )
    chk ( "BYREF AS CONST literal",    p_byref_const( "12345" ), 5 )
    chk ( "BYREF AS CONST temporary",  p_byref_const( u + "xx" ), 15 )
    chk ( "BYVAL AS CONST",            p_byval_const( "abc" ), 3 )

    '' a STRING argument converts on the way in
    chk ( "narrow arg converts",       p_byref_const( "plain string" ), 12 )

    '' a fixed-length argument to a dynamic parameter
    dim as ustring * 16 f = "fixedarg"
    chks( "fixed arg -> dynamic param", p_from_fixed( f ), "FIXEDARG" )

    '' a fixed-length parameter
    dim as ustring * 8 g = "before"
    p_fixed( g )
    chks( "fixed-length parameter",    g, "setfix" )

    '' pointer parameter
    dim as ustring h = "point"
    p_ptr( @h )
    chks( "USTRING PTR parameter",     h, "point viaptr" )

    '' optional
    chks( "optional, omitted",         p_optional( ), "defaulted" )
    chks( "optional, supplied",        p_optional( "given" ), "given" )

    '' overload resolution
    dim as ustring ou = "u"
    dim as string  os = "s"
    dim as wstring * 4 ow = "w"
    chk ( "overload picks ustring",    cint( which_ovl( ou ) = "ustring" ), -1 )
    chk ( "overload picks string",     cint( which_ovl( os ) = "string" ), -1 )
    chk ( "overload picks wstring",    cint( which_ovl( ow ) = "wstring" ), -1 )
end sub


'' =====================================================================
''  6. RETURN VALUES
'' =====================================================================

'' by value, via RETURN
function r_return( ) as ustring
    return "returned"
end function

'' by value, via the function name
function r_fname( ) as ustring
    r_fname = "by name"
end function

'' NOTE: "function r() as ustring * 8" does NOT compile:
''
''   error 55: Fixed-len strings cannot be returned from functions
''
'' identical to STRING * N and WSTRING * N. A fixed-length result would be a
'' pointer to a buffer with nowhere to live. Return the dynamic form instead --
'' the caller can assign it straight into a fixed-length variable.
''
'' (This one was a real USTRING bug, found by writing this file: FIXUSTR was
'' missing from the check in parser-proc.bas, so it was accepted and then
'' MISCOMPILED -- the gcc backend typed the result as a single uint16 and
'' truncated the returned pointer to 16 bits.)
function r_into_fixed( ) as ustring
    return "fixedret"
end function

'' BYREF result -- returns a reference to the caller's own variable
function r_byref( byref u as ustring ) byref as ustring
    return u
end function

'' a result built from several terms
function r_built( byval n as integer ) as ustring
    dim as ustring acc
    for i as integer = 1 to n
        acc += "ab"
    next
    return acc
end function

sub returns( )
    chks( "RETURN a ustring",          r_return(), "returned" )
    chks( "result via function name",  r_fname(), "by name" )
    '' A dynamic result assigned into a fixed-length variable.
    '' NOTE the capacity: USTRING * 8 holds 8 code units INCLUDING the
    '' terminator, so 7 characters of text -- identical to WSTRING * 8, and
    '' unlike STRING * 8 which is not terminated and holds a full 8.
    dim as ustring * 8 into = r_into_fixed()
    chks( "dynamic result -> fixed var", into, "fixedre" )
    chk ( "USTRING * 8 holds 7 units",  len( into ), 7 )
    dim as ustring * 9 into9 = r_into_fixed()
    chks( "USTRING * 9 holds all 8",   into9, "fixedret" )

    '' A BYREF result reads as a reference to the caller's own variable.
    '' NOTE: using it as an assignment TARGET -- r_byref(t) = "x" -- does not
    '' compile, and does not for STRING either (error 58), so that is an FB
    '' rule about string results rather than anything to do with USTRING.
    dim as ustring target = "start"
    chks( "BYREF result reads",        r_byref( target ), "start" )
    chk ( "BYREF result in LEN",       len( r_byref( target ) ), 5 )
    target += "ed"
    chks( "BYREF result tracks source", r_byref( target ), "started" )

    chks( "built result",              r_built(3), "ababab" )
    chk ( "result used in an expr",    len( r_return() & r_fname() ), 15 )

    '' a discarded result must not leak the temp descriptor -- 20000 of them
    '' would exhaust the 256-slot pool if it did
    for i as integer = 1 to 20000
        r_return()
    next
    chks( "pool survives discards",    r_return(), "returned" )
end sub


'' =====================================================================
''  7. [] INDEXING -- READING AND WRITING INDIVIDUAL CODE UNITS
'' =====================================================================
''
'' u[i] is a 16-bit CODE UNIT, zero-based, and O(1) in both directions.
'' It reads as a number (the unit's value), not as a one-character string,
'' which is the same thing STRING and WSTRING indexing does.

sub indexing( )
    '' -- reading
    dim as ustring u = "abc"
    chk( "u[0]",                       u[0], asc("a") )
    chk( "u[1]",                       u[1], asc("b") )
    chk( "u[len-1] is the last unit",  u[len(u)-1], asc("c") )
    chk( "u[len] is the terminator",   u[len(u)], 0 )

    '' -- writing
    u[1] = asc("X")
    chks( "write through u[i]",         u, "aXc" )
    chk ( "and reads back",             u[1], asc("X") )

    '' -- a non-ASCII BMP character reads as its real codepoint
    dim as ustring e = wchr(&h20AC) & "A"        '' euro sign
    chk( "euro unit value",             e[0], 8364 )
    chk( "euro is one unit",            len(e), 2 )

    '' -- an ASTRAL character is a SURROGATE PAIR: two units, one character
    dim as ustring m = "a" & ASTRAL & "b"
    chk( "astral string is 4 units",    len(m), 4 )
    chk( "m[0] is 'a'",                 m[0], asc("a") )
    chk( "m[1] is the HIGH surrogate",  m[1], ASTRAL_HI )
    chk( "m[2] is the LOW surrogate",   m[2], ASTRAL_LO )
    chk( "m[3] is 'b'",                 m[3], asc("b") )

    '' the pair can be rebuilt from its two units
    dim as uinteger cp = &h10000 + ((m[1] - &hD800) shl 10) + (m[2] - &hDC00)
    chk( "units recombine to the codepoint", cp, ASTRAL_CP )

    '' -- indexing a FIXED-length ustring, read and write
    dim as ustring * 8 f = "abc"
    chk ( "fixed f[1]",                 f[1], asc("b") )
    f[1] = asc("Y")
    chks( "write through f[i]",         f, "aYc" )

    '' -- indexing a UDT field, an array element, and through a pointer
    dim as Simple sm
    sm.dyn = "field"
    sm.arr(0) = "array"
    chk( "index a UDT field",           sm.dyn[0], asc("f") )
    sm.dyn[0] = asc("F")
    chks( "write into a UDT field",     sm.dyn, "Field" )
    chk( "index an array field",        sm.arr(0)[0], asc("a") )

    dim as ustring arr(0 to 1)
    arr(1) = "zed"
    chk( "index an array element",      arr(1)[0], asc("z") )

    dim as ustring ptr p = @u
    chk( "index through a pointer",     (*p)[0], asc("a") )

    '' -- [] and STRPTR must agree, since both walk the same buffer
    dim as ushort ptr raw = strptr(e)
    chk( "STRPTR agrees with [] at 0",  raw[0], e[0] )
    chk( "STRPTR agrees with [] at 1",  raw[1], e[1] )

    '' -- indexing in a loop: sum the units, and build a string back from them
    dim as ustring src = "Hello"
    dim as integer sum
    dim as ustring rebuilt
    for i as integer = 0 to len(src) - 1
        sum += src[i]
        rebuilt += wchr( src[i] )
    next
    chk ( "sum of units",               sum, 500 )     '' 72+101+108+108+111
    chks( "rebuilt from its units",     rebuilt, src )

    '' -- reverse a string in place, entirely through []
    dim as ustring rev = "abcdef"
    for i as integer = 0 to len(rev)\2 - 1
        dim as uinteger t = rev[i]
        rev[i] = rev[len(rev)-1-i]
        rev[len(rev)-1-i] = t
    next
    chks( "reversed via []",            rev, "fedcba" )
end sub


'' =====================================================================
''  8. USTRING AS A POINTER
'' =====================================================================
''
'' Two different pointers are in play, and mixing them up is the easy mistake:
''
''   USTRING PTR   points at the DESCRIPTOR -- a whole ustring. Deref it and
''                 you get a ustring you can assign, concatenate and index.
''   USHORT PTR    what STRPTR() gives: the raw UTF-16 CODE UNITS inside it.
''
'' VARPTR gives the first, STRPTR the second, and for a var-len ustring they
'' are different addresses.

'' takes and returns a pointer to a ustring
function first_nonempty( p() as ustring ) as ustring ptr
    for i as integer = lbound(p) to ubound(p)
        if( len( p(i) ) > 0 ) then return @p(i)
    next
    return 0
end function

sub append_through( byval p as ustring ptr, byref extra as const ustring )
    if( p <> 0 ) then *p += extra
end sub

type Holder
    as ustring ptr q
end type

sub pointers( )
    dim as ustring u = "abc"

    '' -- the basics: address-of, deref, and writing through the deref
    dim as ustring ptr p = @u
    chks( "deref reads",               *p, "abc" )
    *p = "xyz"
    chks( "deref writes",              u, "xyz" )
    *p += "!"
    chks( "deref concat-assign",       u, "xyz!" )
    chk ( "LEN through a deref",       len( *p ), 4 )
    chk ( "index through a deref",     (*p)[0], asc("x") )

    '' -- VARPTR is the descriptor, STRPTR is the code units: NOT the same
    dim as ushort ptr raw = strptr(u)
    chk( "VARPTR = the descriptor",    cint( varptr(u) = cast(any ptr, p) ), -1 )
    chk( "STRPTR <> VARPTR",           cint( cast(any ptr, raw) <> varptr(u) ), -1 )
    chk( "STRPTR walks code units",    raw[0], asc("x") )
    raw[0] = asc("X")
    chks( "writing raw units shows up", u, "Xyz!" )

    '' -- pointer ARITHMETIC over an array of ustrings
    dim as ustring arr(0 to 2) = { "a", "b", "c" }
    dim as ustring ptr ap = @arr(0)
    chks( "ptr + 2",                   *(ap + 2), "c" )
    chks( "ptr[1] indexes the array",  ap[1], "b" )
    ap[1] = "B"
    chks( "write via ptr[i]",          arr(1), "B" )

    '' -- double indirection
    dim as ustring ptr ptr pp = @p
    chks( "USTRING PTR PTR",           **pp, "Xyz!" )

    '' -- heap allocation with NEW / DELETE
    dim as ustring ptr heap_ = new ustring
    *heap_ = "heaped"
    *heap_ += " and grown"
    chks( "NEW ustring",               *heap_, "heaped and grown" )
    delete heap_

    '' an array of them
    dim as ustring ptr many = new ustring[3]
    many[0] = "zero" : many[2] = "two"
    chks( "NEW ustring[3]",            many[0] & many[2], "zerotwo" )
    delete[] many

    '' -- a pointer stored in a UDT, and an array of pointers
    dim as Holder h
    h.q = @u
    chks( "pointer field in a UDT",    *(h.q), "Xyz!" )

    dim as ustring ptr parr(0 to 1)
    parr(0) = @u
    parr(1) = @arr(0)
    chks( "array of USTRING PTR",      *(parr(0)) & *(parr(1)), "Xyz!a" )

    '' -- passing and returning pointers
    dim as ustring blanks(0 to 2)
    blanks(1) = "found"
    dim as ustring ptr got = first_nonempty( blanks() )
    chk ( "returned pointer is valid", cint( got <> 0 ), -1 )
    chks( "returned pointer derefs",   *got, "found" )

    append_through( got, " it" )
    chks( "callee wrote through it",   blanks(1), "found it" )

    '' a null result, and the guard that handles it
    dim as ustring empties(0 to 1)
    chk( "null when nothing matches",  cint( first_nonempty( empties() ) = 0 ), -1 )
    append_through( 0, "ignored" )   '' must not crash
    chk( "null guard survived",        1, 1 )

    '' -- a fixed-length ustring: the VARIABLE is the buffer, so STRPTR and
    ''    VARPTR agree, unlike the var-len case above
    dim as ustring * 8 f = "fix"
    dim as ushort ptr fraw = strptr(f)
    chk ( "fixed: STRPTR = VARPTR",    cint( cast(any ptr, fraw) = varptr(f) ), -1 )
    fraw[0] = asc("F")
    chks( "fixed: write via STRPTR",   f, "Fix" )
end sub


'' =====================================================================
''  8. UNICODE AND INTRINSICS IN ALL OF THE ABOVE
'' =====================================================================

sub unicode_( )
    '' a UDT field, an array element and a fixed field all holding non-ASCII
    dim as Simple s
    s.dyn = "caf" & wchr(&hE9)
    s.fix = wchr(&h20AC) & "12"
    s.arr(0) = ASTRAL

    chk ( "accented field is 4 units",  len(s.dyn), 4 )
    chk ( "euro in a fixed field",      s.fix[0], &h20AC )
    chk ( "astral is 2 code units",     len(s.arr(0)), 2 )

    '' intrinsics
    dim as ustring u = "  Grüße, Welt  "
    chks( "TRIM",                       trim(u), "Grüße, Welt" )
    '' SIMPLE case mapping only: one code unit in, one out. The sharp s would
    '' upper-case to "SS", which changes the length, so it is left alone --
    '' the same rule every other FB string type follows.
    chks( "UCASE (simple mapping)",     ucase(trim(u)), "GRÜßE, WELT" )
    chks( "LEFT",                       left(trim(u), 5), "Grüße" )
    chks( "RIGHT",                      right(trim(u), 4), "Welt" )
    chks( "MID",                        mid(trim(u), 8, 4), "Welt" )
    chk ( "INSTR",                      instr(trim(u), "Welt"), 8 )

    '' MID statement
    dim as ustring m = "abcdef"
    mid(m, 2, 3) = "XYZ"
    chks( "MID statement",              m, "aXYZef" )

    '' SWAP between a UDT field and a local
    dim as ustring other = "swapped"
    swap s.dyn, other
    chks( "SWAP UDT field",             s.dyn, "swapped" )
    chks( "SWAP local",                 other, "caf" & wchr(&hE9) )

    '' round trip through the other string types
    dim as string  narrow = trim(u)
    dim as wstring * 32 wide = trim(u)
    '' NOTE: CAST(ustring, x) does not compile -- but neither does
    '' CAST(string, x); casting TO a string type is not an fbc feature. Plain
    '' assignment is the conversion, and it is implicit in both directions.
    dim as ustring back_n = narrow
    dim as ustring back_w = wide
    chks( "-> STRING -> back",          back_n, trim(u) )
    chks( "-> WSTRING -> back",         back_w, trim(u) )
end sub


'' =====================================================================

print "USTRING usage showcase"
print

decl_forms( )

dim as integer l1, l2
static_counter( l1 )
static_counter( l2 )
chk( "STATIC local persists", l2 - l1, 2 )

arrays( )
udts( )
classes( )
params( )
returns( )
indexing( )
pointers( )
unicode_( )

print
print g_run; " checks,"; g_fail; " failed"
if( g_fail <> 0 ) then end 1

