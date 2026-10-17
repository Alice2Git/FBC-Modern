'' Module A of naked-private-mm.bmk.  Includes the header with the private
'' naked NakedInc exactly as the driver does, and defines a PUBLIC naked
'' procedure the driver calls -- that one must still be '.globl'.

#include once "naked-private-mm.bi"

#if defined( __FB_X86__ )

'' x * 2
function NakedPublicDouble naked cdecl( byval x as long ) as long
	asm
		#if defined( __FB_64BIT__ )
			#if defined( __FB_WIN32__ )
				lea eax, [rcx+rcx]
			#else
				lea eax, [rdi+rdi]
			#endif
		#else
			mov eax, [esp+4]
			add eax, eax
		#endif
		ret
	end asm
end function

#else

function NakedPublicDouble cdecl( byval x as long ) as long
	return x * 2
end function

#endif

function ModuleA( ) as long
	return NakedInc( 9 )
end function
