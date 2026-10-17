'' Header for naked-private-mm.bmk, included by both modules -- see that file.

#ifndef __NAKED_PRIVATE_MM_BI__
#define __NAKED_PRIVATE_MM_BI__

#if defined( __FB_X86__ )

'' x + 1
private function NakedInc naked cdecl( byval x as long ) as long
	asm
		#if defined( __FB_64BIT__ )
			#if defined( __FB_WIN32__ )
				lea eax, [rcx+1]
			#else
				lea eax, [rdi+1]
			#endif
		#else
			mov eax, [esp+4]
			inc eax
		#endif
		ret
	end asm
end function

#else

'' no naked asm to write here; keep the shape of the test
private function NakedInc cdecl( byval x as long ) as long
	return x + 1
end function

#endif

declare function NakedPublicDouble cdecl( byval x as long ) as long
declare function ModuleA( ) as long

#endif
