'' intrinsic runtime lib ustring functions (var-len UTF-16 strings)
''
'' The ustring twin of rtl-string.bas. Every entry point takes (ptr, size)
'' pairs, where the size discriminates the three forms an argument can take --
'' see FB_USTRSIZEVARLEN in src/rtlib/fb_ustring.h. rtlCalcStrLen() produces
'' that value on the compiler side.

#include once "fb.bi"
#include once "fbint.bi"
#include once "ast.bi"
#include once "rtl.bi"

	dim shared as FB_RTL_PROCDEF funcdata( 0 to ... ) = _
	{ _
		/' function fb_UStrInit( byref dst as any, byval dst_size as const integer, _
				byref src as const any, byval src_size as const integer, _
				byval fillrem as const long = 1 ) as ustring '/ _
		( _
			@FB_RTL_USTRINIT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' function fb_UStrAssign( ... ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGN, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' sub fb_UStrDelete( byref str as const ustring ) '/ _
		( _
			@FB_RTL_USTRDELETE, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeSetIsConst( FB_DATATYPE_USTRING ), FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_hUStrDelTemp( byref str as const ustring ) as long '/ _
		( _
			@FB_RTL_HUSTRDELTEMP, NULL, _
			FB_DATATYPE_LONG, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeSetIsConst( FB_DATATYPE_USTRING ), FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_UStrConcat( byref dst as ustring, _
				byref str1 as const any, byval str1_size as const integer, _
				byref str2 as const any, byval str2_size as const integer ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCAT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatAssign( ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATASSIGN, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 1 ) _
			} _
		), _
		/' function fb_UStrCompare( byref str1 as const any, byval str1_size as const integer, _
				byref str2 as const any, byval str2_size as const integer ) as long '/ _
		( _
			@FB_RTL_USTRCOMPARE, NULL, _
			FB_DATATYPE_LONG, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrLen( byref str as const any, byval str_size as const integer ) as integer '/ _
		( _
			@FB_RTL_USTRLEN, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrAssignFromA( byref dst as any, byval dst_size as const integer, _
				byref src as const any, byval src_size as const integer, _
				byval fillrem as const long, byval is_init as const long ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGNFROMA, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			6, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_UStrAssignToA( ... ) as string '/ _
		( _
			@FB_RTL_USTRASSIGNTOA, NULL, _
			FB_DATATYPE_STRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			6, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_StrToUStr( byref src as const any, byval src_size as const integer ) as ustring '/ _
		( _
			@FB_RTL_STR2USTR, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrToStr( byref src as const any, byval src_size as const integer ) as string '/ _
		( _
			@FB_RTL_USTR2STR, NULL, _
			FB_DATATYPE_STRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatAU( byref dst as ustring, ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATAU, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrConcatUA( byref dst as ustring, ... ) as ustring '/ _
		( _
			@FB_RTL_USTRCONCATUA, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrAllocTempResult( byref src as ustring ) as ustring '/ _
		( _
			@FB_RTL_USTRALLOCTEMPRES, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( FB_DATATYPE_USTRING, FB_PARAMMODE_BYREF, FALSE ) _
			} _
		), _
		/' function fb_UStrAssignFromW( byref dst as any, byval dst_size as const integer, _
				byval src as const wstring ptr, byval fillrem as const long, _
				byval is_init as const long ) as ustring '/ _
		( _
			@FB_RTL_USTRASSIGNFROMW, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeAddrOf( typeSetIsConst( FB_DATATYPE_WCHAR ) ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ), _
				( typeSetIsConst( FB_DATATYPE_LONG ), FB_PARAMMODE_BYVAL, TRUE, 0 ) _
			} _
		), _
		/' function fb_UStrAssignToW( byval dst as wstring ptr, byval dst_chars as const integer, _
				byref src as const any, byval src_size as const integer ) as wstring ptr '/ _
		( _
			@FB_RTL_USTRASSIGNTOW, NULL, _
			typeAddrOf( FB_DATATYPE_WCHAR ), FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeAddrOf( FB_DATATYPE_WCHAR ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_WstrToUStr( byval src as const wstring ptr ) as ustring '/ _
		( _
			@FB_RTL_WSTR2USTR, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeAddrOf( typeSetIsConst( FB_DATATYPE_WCHAR ) ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' function fb_UStrToWstr( byref src as const any, byval src_size as const integer ) as wstring ptr '/ _
		( _
			@FB_RTL_USTR2WSTR, NULL, _
			typeAddrOf( FB_DATATYPE_WCHAR ), FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLeft( src, src_size, units ) '/ _
		( _
			@FB_RTL_USTRLEFT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrRight( src, src_size, units ) '/ _
		( _
			@FB_RTL_USTRRIGHT, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrMid( src, src_size, start, units ) '/ _
		( _
			@FB_RTL_USTRMID, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrAssignMid( dst, dst_size, start, units, src, src_size ) '/ _
		( _
			@FB_RTL_USTRASSIGNMID, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			6, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrSpace( units ) '/ _
		( _
			@FB_RTL_USTRSPACE, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			1, _
			{ _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrFill1( units, unit ) '/ _
		( _
			@FB_RTL_USTRFILL1, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrFill2( units, src, src_size ) '/ _
		( _
			@FB_RTL_USTRFILL2, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrTrim( src, src_size ) '/ _
		( _
			@FB_RTL_USTRTRIM, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLTrim( src, src_size ) '/ _
		( _
			@FB_RTL_USTRLTRIM, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrRTrim( src, src_size ) '/ _
		( _
			@FB_RTL_USTRRTRIM, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrTrimEx( src, src_size, pat, pat_size ) '/ _
		( _
			@FB_RTL_USTRTRIMEX, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLTrimEx( src, src_size, pat, pat_size ) '/ _
		( _
			@FB_RTL_USTRLTRIMEX, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrRTrimEx( src, src_size, pat, pat_size ) '/ _
		( _
			@FB_RTL_USTRRTRIMEX, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrTrimAny( src, src_size, set, set_size ) '/ _
		( _
			@FB_RTL_USTRTRIMANY, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLTrimAny( src, src_size, set, set_size ) '/ _
		( _
			@FB_RTL_USTRLTRIMANY, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrRTrimAny( src, src_size, set, set_size ) '/ _
		( _
			@FB_RTL_USTRRTRIMANY, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrInstr( start, src, src_size, pat, pat_size ) '/ _
		( _
			@FB_RTL_USTRINSTR, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrInstrAny( start, src, src_size, set, set_size ) '/ _
		( _
			@FB_RTL_USTRINSTRANY, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrInstrRev( src, src_size, pat, pat_size, start ) '/ _
		( _
			@FB_RTL_USTRINSTRREV, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrInstrRevAny( src, src_size, set, set_size, start ) '/ _
		( _
			@FB_RTL_USTRINSTRREVANY, NULL, _
			FB_DATATYPE_INTEGER, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			5, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrUcase( src, src_size ) '/ _
		( _
			@FB_RTL_USTRUCASE, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLcase( src, src_size ) '/ _
		( _
			@FB_RTL_USTRLCASE, NULL, _
			FB_DATATYPE_USTRING, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			2, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrAsc( src, src_size, pos ) '/ _
		( _
			@FB_RTL_USTRASC, NULL, _
			FB_DATATYPE_LONG, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			3, _
			{ _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrLset( dst, dst_size, src, src_size ) '/ _
		( _
			@FB_RTL_USTRLSET, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrRset( dst, dst_size, src, src_size ) '/ _
		( _
			@FB_RTL_USTRRSET, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_VOID ), FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' fb_UStrSwap( str1, size1, str2, size2 ) '/ _
		( _
			@FB_RTL_USTRSWAP, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			4, _
			{ _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ), _
				( FB_DATATYPE_VOID, FB_PARAMMODE_BYREF, FALSE ), _
				( typeSetIsConst( FB_DATATYPE_INTEGER ), FB_PARAMMODE_BYVAL, FALSE ) _
			} _
		), _
		/' end of table '/ _
		( _
			NULL, NULL, _
			FB_DATATYPE_VOID, FB_FUNCMODE_FBCALL, _
			NULL, FB_RTL_OPT_NONE, _
			0, _
			{ ( 0, 0, FALSE ) } _
		) _
	 }

'':::::
sub rtlUStringModInit( )

	rtlAddIntrinsicProcs( @funcdata(0) )

end sub

'':::::
sub rtlUStringModEnd( )

	'' procs will be deleted when symbEnd is called

end sub

'':::::
'' u = src   (or the initializing form, which skips deleting the old contents)
function rtlUStrAssign _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr, _
		byval is_init as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer ddtype = any, sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	ddtype = astGetDataType( dst )
	sdtype = astGetDataType( src )

	'' WSTRING on either side is resolved by converting that side first, then
	'' falling into the ordinary path. Doing it here rather than adding two more
	'' entry-point shapes keeps the wstring temp handling in the one place fbc
	'' already gets it right.
	if( typeGet( sdtype ) = FB_DATATYPE_WCHAR ) then
		src = rtlWstrToUStr( src )
		sdtype = astGetDataType( src )
	elseif( typeGet( ddtype ) = FB_DATATYPE_WCHAR ) then
		'' ustring -> wstring, bounded by the destination's declared capacity
		return rtlUStrAssignToW( dst, src )
	end if

	'' Four combinations, because a ustring may be assigned from (or to) the
	'' narrow world. The conversion entry points take is_init as an explicit
	'' argument rather than having separate Init/Assign twins.
	dim as integer needs_conv = (typeIsUstring( ddtype ) <> typeIsUstring( sdtype ))

	if( needs_conv ) then
		if( typeIsUstring( ddtype ) ) then
			proc = astNewCALL( PROCLOOKUP( USTRASSIGNFROMA ) )
		else
			proc = astNewCALL( PROCLOOKUP( USTRASSIGNTOA ) )
		end if
	elseif( is_init ) then
		proc = astNewCALL( PROCLOOKUP( USTRINIT ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRASSIGN ) )
	end if

	'' NOTE: rtlCalcStrLen() must run BEFORE astNewARG(), because the latter
	'' can rewrite the expression (address-of etc) and lose the symbol the
	'' length is derived from. Same rule as the narrow builders.
	dlgt = rtlCalcStrLen( dst, ddtype )

	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	slgt = rtlCalcStrLen( src, sdtype )

	if( astNewARG( proc, src ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	'' fillrem: only a fixed-length destination needs its tail zeroed
	dim as integer fillrem = any
	if( typeIsUstring( ddtype ) ) then
		fillrem = (ddtype = FB_DATATYPE_FIXUSTR)
	else
		fillrem = (ddtype = FB_DATATYPE_FIXSTR)
	end if
	if( astNewARG( proc, astNewCONSTi( fillrem ) ) = NULL ) then exit function

	'' the conversion entry points carry is_init as a sixth argument
	if( needs_conv ) then
		if( astNewARG( proc, astNewCONSTi( is_init ) ) = NULL ) then exit function
	end if

	'' the rtlib returns a pointer to the destination; nothing consumes it
	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Mixed concatenation: one side ustring, the other narrow. The narrow side is
'' decoded to UTF-16 and the result is a ustring, so text never degrades to
'' bytes just because it was concatenated with a STRING.
function rtlUStrConcatMixed _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr tmp = any
	dim as longint str1len = any, str2len = any

	function = NULL

	if( typeIsUstring( sdtype1 ) ) then
		proc = astNewCALL( PROCLOOKUP( USTRCONCATUA ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRCONCATAU ) )
	end if

	tmp = symbAddTempVar( FB_DATATYPE_USTRING )

	if( astNewARG( proc, astNewLINK( astBuildTempVarClear( tmp ), _
	                                 astNewVAR( tmp ), _
	                                 AST_LINK_RETURN_RIGHT ) ) = NULL ) then
		exit function
	end if

	'' lengths before astNewARG(), as everywhere else
	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' a + b -> a fresh TEMP descriptor, so the assignment that consumes it can
'' steal the buffer rather than copy it
function rtlUStrConcat _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr tmp = any
	dim as longint str1len = any, str2len = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRCONCAT ) )

	'' byref dst as ustring -- a temp the rtlib fills in and flags as temp
	tmp = symbAddTempVar( FB_DATATYPE_USTRING )

	if( astNewARG( proc, astNewLINK( astBuildTempVarClear( tmp ), _
	                                 astNewVAR( tmp ), _
	                                 AST_LINK_RETURN_RIGHT ) ) = NULL ) then
		exit function
	end if

	'' lengths first -- see the note in rtlUStrAssign()
	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' u &= src
function rtlUStrConcatAssign _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer ddtype = any, sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	ddtype = astGetDataType( dst )
	sdtype = astGetDataType( src )

	proc = astNewCALL( PROCLOOKUP( USTRCONCATASSIGN ) )

	dlgt = rtlCalcStrLen( dst, ddtype )
	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	slgt = rtlCalcStrLen( src, sdtype )
	if( astNewARG( proc, src ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	if( astNewARG( proc, astNewCONSTi( ddtype = FB_DATATYPE_FIXUSTR ) ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Convert a narrow string expression to a ustring temp. Used where an operation
'' has no mixed form of its own (comparison), so both sides can be made ustrings
'' first and the normal path taken.
'' Move a FUNCTION's ustring result out of its dying stack frame into a pooled
'' temp descriptor, and return a pointer to that.
function rtlUStrAllocTempResult _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRALLOCTEMPRES ) )

	if( astNewARG( proc, expr ) = NULL ) then exit function

	function = proc

end function

'':::::
'' u -> wstring destination.
''
'' Needs its own entry point rather than going through rtlWstrAssign(): the
'' destination's capacity has to be passed so the copy can be clamped, and the
'' runtime re-encodes (a copy where wchar is 16 bits, UTF-16 -> UTF-32 where it
'' is 32).
function rtlUStrAssignToW _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer sdtype = any
	dim as longint dlgt = any, slgt = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRASSIGNTOW ) )

	'' capacity INCLUDING the terminator, as rtlCalcStrLen() reports for WCHAR
	dlgt = rtlCalcStrLen( dst, astGetDataType( dst ) )
	if( astNewARG( proc, dst ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( dlgt ) ) = NULL ) then exit function

	sdtype = astGetDataType( src )
	slgt = rtlCalcStrLen( src, sdtype )
	if( astNewARG( proc, src, sdtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( slgt ) ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
'' Convert a wstring expression to a ustring temp.
''
'' On a target where wchar is 16 bits this is a straight copy; on Linux it is a
'' UTF-32 -> UTF-16 re-encode. The compiler cannot tell the two apart here --
'' the runtime branches on sizeof(FB_WCHAR).
function rtlWstrToUStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( WSTR2USTR ) )

	'' byval src as wchar ptr -- let astNewARG() do the decay, as rtlWstrLen()
	'' does; forcing the dtype here passes a WSTRING * N by value instead
	if( astNewARG( proc, expr ) = NULL ) then exit function

	function = proc

end function

'':::::
'' Convert a ustring expression to a freshly allocated wchar buffer, which the
'' caller must delete -- same contract as every other wstring-returning rtlib
'' function.
function rtlUStrToWstr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTR2WSTR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlStrToUStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( STR2USTR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' Convert a ustring expression to a narrow (UTF-8) string temp.
function rtlUStrToStr _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTR2STR ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlUStrDelete _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	'' A CALL result is already a temp descriptor from the pool, so it must go
	'' back through fb_hUStrDelTemp (which frees the descriptor slot too).
	'' A variable's own descriptor is not pooled -- only its data is freed.
	if( astIsCALL( expr ) ) then
		proc = astNewCALL( PROCLOOKUP( HUSTRDELTEMP ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRDELETE ) )
	end if

	if( astNewARG( proc, expr ) = NULL ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc

end function

'':::::
function rtlUStrLen _
	( _
		byval expr as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as integer dtype = any
	dim as longint lgt = any

	function = NULL

	dtype = astGetDataType( expr )

	proc = astNewCALL( PROCLOOKUP( USTRLEN ) )

	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then exit function

	function = proc

end function

'':::::
function rtlUStrCompare _
	( _
		byval str1 as ASTNODE ptr, _
		byval sdtype1 as integer, _
		byval str2 as ASTNODE ptr, _
		byval sdtype2 as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as longint str1len = any, str2len = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRCOMPARE ) )

	str1len = rtlCalcStrLen( str1, sdtype1 )
	str2len = rtlCalcStrLen( str2, sdtype2 )

	if( astNewARG( proc, str1, sdtype1 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str1len ) ) = NULL ) then exit function
	if( astNewARG( proc, str2, sdtype2 ) = NULL ) then exit function
	if( astNewARG( proc, astNewCONSTi( str2len ) ) = NULL ) then exit function

	function = proc

end function

'':::::
'' Push a ustring operand as the (ptr, size) pair every ustring entry point
'' takes. The length MUST be computed before astNewARG(), which can rewrite the
'' expression and lose the symbol the length comes from.
private function hPushUStrArg _
	( _
		byval proc as ASTNODE ptr, _
		byval expr as ASTNODE ptr _
	) as integer

	dim as integer dtype = any
	dim as longint lgt = any

	'' anything not already a ustring is converted first, so the runtime never
	'' sees a byte buffer described as code units
	expr = astNewUStrConv( expr )

	dtype = astGetDataType( expr )
	lgt = rtlCalcStrLen( expr, dtype )

	if( astNewARG( proc, expr, dtype ) = NULL ) then return FALSE
	if( astNewARG( proc, astNewCONSTi( lgt ) ) = NULL ) then return FALSE

	function = TRUE
end function

'':::::
function rtlUStrLeft _
	( _
		byval nd_str as ASTNODE ptr, _
		byval units as ASTNODE ptr, _
		byval is_right as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( is_right ) then
		proc = astNewCALL( PROCLOOKUP( USTRRIGHT ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRLEFT ) )
	end if

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function
	if( astNewARG( proc, units ) = NULL ) then exit function

	function = proc
end function

'':::::
function rtlUStrMid _
	( _
		byval nd_str as ASTNODE ptr, _
		byval start as ASTNODE ptr, _
		byval units as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRMID ) )

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function
	if( astNewARG( proc, start ) = NULL ) then exit function

	'' a negative count means "to the end", which is what the parser passes
	'' when the third argument was omitted
	if( units = NULL ) then
		units = astNewCONSTi( -1 )
	end if
	if( astNewARG( proc, units ) = NULL ) then exit function

	function = proc
end function

'':::::
function rtlUStrAssignMid _
	( _
		byval dst as ASTNODE ptr, _
		byval start as ASTNODE ptr, _
		byval units as ASTNODE ptr, _
		byval src as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRASSIGNMID ) )

	if( hPushUStrArg( proc, dst ) = FALSE ) then exit function
	if( astNewARG( proc, start ) = NULL ) then exit function

	if( units = NULL ) then
		units = astNewCONSTi( -1 )
	end if
	if( astNewARG( proc, units ) = NULL ) then exit function

	if( hPushUStrArg( proc, src ) = FALSE ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	'' EMIT it. cMidStmt only checks the result for NULL and never adds the
	'' node itself -- the narrow rtlStrAssignMid astAdd()s before returning, so
	'' this must too. Without it the MID statement compiled, reported success,
	'' and silently did nothing. (Same mistake as rtlStrLRSet in phase 3.)
	astAdd( proc )

	function = proc
end function

'':::::
function rtlUStrTrim _
	( _
		byval nd_str as ASTNODE ptr, _
		byval pattern as ASTNODE ptr, _
		byval is_any as integer, _
		byval mode as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any
	dim as FBSYMBOL ptr f = any

	function = NULL

	'' mode: 0 = trim, 1 = ltrim, 2 = rtrim
	if( is_any ) then
		select case mode
		case 1 : f = PROCLOOKUP( USTRLTRIMANY )
		case 2 : f = PROCLOOKUP( USTRRTRIMANY )
		case else : f = PROCLOOKUP( USTRTRIMANY )
		end select
	elseif( pattern <> NULL ) then
		select case mode
		case 1 : f = PROCLOOKUP( USTRLTRIMEX )
		case 2 : f = PROCLOOKUP( USTRRTRIMEX )
		case else : f = PROCLOOKUP( USTRTRIMEX )
		end select
	else
		select case mode
		case 1 : f = PROCLOOKUP( USTRLTRIM )
		case 2 : f = PROCLOOKUP( USTRRTRIM )
		case else : f = PROCLOOKUP( USTRTRIM )
		end select
	end if

	proc = astNewCALL( f )

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function

	if( (pattern <> NULL) or is_any ) then
		if( hPushUStrArg( proc, pattern ) = FALSE ) then exit function
	end if

	function = proc
end function

'':::::
function rtlUStrInstr _
	( _
		byval start as ASTNODE ptr, _
		byval nd_str as ASTNODE ptr, _
		byval pattern as ASTNODE ptr, _
		byval is_any as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( is_any ) then
		proc = astNewCALL( PROCLOOKUP( USTRINSTRANY ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRINSTR ) )
	end if

	if( start = NULL ) then
		start = astNewCONSTi( 1 )
	end if
	if( astNewARG( proc, start ) = NULL ) then exit function

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function
	if( hPushUStrArg( proc, pattern ) = FALSE ) then exit function

	function = proc
end function

'':::::
function rtlUStrInstrRev _
	( _
		byval nd_str as ASTNODE ptr, _
		byval pattern as ASTNODE ptr, _
		byval start as ASTNODE ptr, _
		byval is_any as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( is_any ) then
		proc = astNewCALL( PROCLOOKUP( USTRINSTRREVANY ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRINSTRREV ) )
	end if

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function
	if( hPushUStrArg( proc, pattern ) = FALSE ) then exit function

	'' a negative start means "from the end"
	if( start = NULL ) then
		start = astNewCONSTi( -1 )
	end if
	if( astNewARG( proc, start ) = NULL ) then exit function

	function = proc
end function

'':::::
function rtlUStrCase _
	( _
		byval nd_str as ASTNODE ptr, _
		byval is_upper as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( is_upper ) then
		proc = astNewCALL( PROCLOOKUP( USTRUCASE ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRLCASE ) )
	end if

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function

	function = proc
end function

'':::::
'' SPACE( n ) and STRING( n, x ) for ustrings
function rtlUStrFill _
	( _
		byval units as ASTNODE ptr, _
		byval fill as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( fill = NULL ) then
		proc = astNewCALL( PROCLOOKUP( USTRSPACE ) )
		if( astNewARG( proc, units ) = NULL ) then exit function
	elseif( typeGetClass( astGetDataType( fill ) ) = FB_DATACLASS_INTEGER ) then
		proc = astNewCALL( PROCLOOKUP( USTRFILL1 ) )
		if( astNewARG( proc, units ) = NULL ) then exit function
		if( astNewARG( proc, fill ) = NULL ) then exit function
	else
		proc = astNewCALL( PROCLOOKUP( USTRFILL2 ) )
		if( astNewARG( proc, units ) = NULL ) then exit function
		if( hPushUStrArg( proc, fill ) = FALSE ) then exit function
	end if

	function = proc
end function

'':::::
function rtlUStrAsc _
	( _
		byval nd_str as ASTNODE ptr, _
		byval nd_pos as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRASC ) )

	if( hPushUStrArg( proc, nd_str ) = FALSE ) then exit function

	if( nd_pos = NULL ) then
		nd_pos = astNewCONSTi( 1 )
	end if
	if( astNewARG( proc, nd_pos ) = NULL ) then exit function

	function = proc
end function

'':::::
function rtlUStrLRSet _
	( _
		byval dst as ASTNODE ptr, _
		byval src as ASTNODE ptr, _
		byval is_rset as integer _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	if( is_rset ) then
		proc = astNewCALL( PROCLOOKUP( USTRRSET ) )
	else
		proc = astNewCALL( PROCLOOKUP( USTRLSET ) )
	end if

	if( hPushUStrArg( proc, dst ) = FALSE ) then exit function
	if( hPushUStrArg( proc, src ) = FALSE ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc
end function

'':::::
function rtlUStrSwap _
	( _
		byval a as ASTNODE ptr, _
		byval b as ASTNODE ptr _
	) as ASTNODE ptr

	dim as ASTNODE ptr proc = any

	function = NULL

	proc = astNewCALL( PROCLOOKUP( USTRSWAP ) )

	if( hPushUStrArg( proc, a ) = FALSE ) then exit function
	if( hPushUStrArg( proc, b ) = FALSE ) then exit function

	astSetType( proc, FB_DATATYPE_VOID, NULL )

	function = proc
end function
