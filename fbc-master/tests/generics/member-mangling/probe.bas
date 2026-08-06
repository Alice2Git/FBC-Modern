' TEST_MODE : MULTI_MODULE_TEST

'' The mangling assertions.
''
'' Each ALIAS below is the exact Itanium name the corresponding method of
'' Box( of ... ) is expected to have (see boxgen.bi, included only by main.bas).
'' Taking their addresses is what forces the linker to resolve them; a mangling
'' change makes the link fail.  Merely DECLARING them would prove nothing --
'' an unreferenced declare emits no relocation and links against anything.
''
'' They are never called: the signatures here are deliberately loose ('any ptr'
'' for the hidden THIS), which is fine for resolving a name and would be an ABI
'' mismatch for a call.
''
'' The names were checked against x86_64-w64-mingw32-g++ for the equivalent C++
'' template and are byte-identical apart from the method name, which fbc
'' up-cases.  Two things they pin:
''
''   - the type argument is spelled out, never emitted as a substitution.
''     hMangleNamespace mangles a parent namespace twice -- once into a
''     throwaway string, purely to populate the abbreviation table -- and that
''     warm-up pass used to register the type arguments, so the real pass
''     emitted 'S_' for them.  Every instantiation whose argument was
''     abbreviation-eligible then collapsed onto ONE external name:
''     Box(of integer), Box(of string), Box(of MyUdt) and Box(of long ptr) all
''     mangled as _ZN3BoxIS_E..., which c++filt reads back as Box<Box>.
''
''   - the template NAME occupies substitution slot 0, so an argument-typed
''     parameter is S0_ and not S_ -- which is what g++ emits.

'' Box<int>::TAKE(int) -- 'i' because fbc's LONG is C's int
declare function t_long alias "_ZN3BoxIiE4TAKEEi" _
	( byval this_ as any ptr, byval a as long ) as long

'' Box<double>::TAKE(double)
declare function t_double alias "_ZN3BoxIdE4TAKEEd" _
	( byval this_ as any ptr, byval a as double ) as double

'' Box<Box<int> >::TAKE(Box<int>).  Slots run: 0 = the outer template name Box,
'' 1 = the inner one, 2 = Box<int> itself -- so the parameter is S1_.
''
'' g++ writes _ZN3BoxS_IiEE4takeES0_ for the same thing: it abbreviates the
'' inner 'Box' where fbc spells it out, because fbc suppresses substitution
'' INSIDE a template argument list.  Both demangle to the same type, and the
'' single-level cases above are byte-identical to g++; only nesting diverges,
'' and fbc generics are not C++ templates to interoperate with anyway.
declare function t_nested alias "_ZN3BoxI3BoxIiEE4TAKEES1_" _
	( byval this_ as any ptr, byval a as any ptr ) as any ptr

'' The generic GLOBAL operators.  Both are byte-identical to what
'' x86_64-w64-mingw32-g++ emits for the equivalent C++ template -- including the
'' substitution index, which is the part that was wrong: the synthetic namespace
'' wrapping an instantiation emits nothing, but the mangler's abbreviation
'' warm-up pass used to register it anyway, so every back-reference came out one
'' too high (_ZplR3BoxIdES2_, which c++filt cannot read at all).
''
'' Slots for operator+(Box<double>&, Box<double>&): 0 = the template name Box,
'' 1 = Box<double> (double is a builtin and not a candidate), 2 = the reference
'' -- so the second parameter is S1_.
declare function o_long alias "_ZplR3BoxIiES1_" _
	( byval a as any ptr, byval b as any ptr ) as any ptr

declare function o_double alias "_ZplR3BoxIdES1_" _
	( byval a as any ptr, byval b as any ptr ) as any ptr

function probe_addrs( ) as integer
	dim as any ptr p( 0 to 4 ) = { @t_long, @t_double, @t_nested, @o_long, @o_double }
	dim as integer n = 0

	for i as integer = 0 to 4
		if p( i ) <> 0 then
			n += 1
		end if
	next

	function = n
end function
