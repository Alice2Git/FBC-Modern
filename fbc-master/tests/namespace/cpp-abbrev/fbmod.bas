' TEST_MODE : MULTI_MODULE_TEST

'' See cppmod.cpp -- this checks that fbc's Itanium substitution
'' (abbreviation) encoding agrees with g++ at sequence ids past 'W'.
''
'' The calls below must not be wrapped in ASSERT(): that macro expands to
'' nothing without -g, which would leave no reference for the linker to
'' resolve and the test would pass even with broken mangling.

extern "c++"
	namespace nsab
		type T1 : v as long : end type
		type T2 : v as long : end type
		type T3 : v as long : end type
		type T4 : v as long : end type
		type T5 : v as long : end type
		type T6 : v as long : end type
		type T7 : v as long : end type
		type T8 : v as long : end type
		type T9 : v as long : end type
		type T10 : v as long : end type
		type T11 : v as long : end type
		type T12 : v as long : end type
		type T13 : v as long : end type
		type T14 : v as long : end type
		type T15 : v as long : end type
		type T16 : v as long : end type
		type T17 : v as long : end type
		type T18 : v as long : end type
		type T19 : v as long : end type
		declare function f17( byval p1 as T1 ptr, byval p2 as T2 ptr, byval p3 as T3 ptr, byval p4 as T4 ptr, byval p5 as T5 ptr, byval p6 as T6 ptr, byval p7 as T7 ptr, byval p8 as T8 ptr, byval p9 as T9 ptr, byval p10 as T10 ptr, byval p11 as T11 ptr, byval p12 as T12 ptr, byval p13 as T13 ptr, byval p14 as T14 ptr, byval p15 as T15 ptr, byval p16 as T16 ptr, byval p17 as T17 ptr, byval r as T17 ptr ) as long
		declare function f19( byval p1 as T1 ptr, byval p2 as T2 ptr, byval p3 as T3 ptr, byval p4 as T4 ptr, byval p5 as T5 ptr, byval p6 as T6 ptr, byval p7 as T7 ptr, byval p8 as T8 ptr, byval p9 as T9 ptr, byval p10 as T10 ptr, byval p11 as T11 ptr, byval p12 as T12 ptr, byval p13 as T13 ptr, byval p14 as T14 ptr, byval p15 as T15 ptr, byval p16 as T16 ptr, byval p17 as T17 ptr, byval p18 as T18 ptr, byval p19 as T19 ptr, byval r as T19 ptr ) as long
	end namespace
end extern

dim as nsab.T1 v17_1 = ( 1 )
dim as nsab.T2 v17_2 = ( 1 )
dim as nsab.T3 v17_3 = ( 1 )
dim as nsab.T4 v17_4 = ( 1 )
dim as nsab.T5 v17_5 = ( 1 )
dim as nsab.T6 v17_6 = ( 1 )
dim as nsab.T7 v17_7 = ( 1 )
dim as nsab.T8 v17_8 = ( 1 )
dim as nsab.T9 v17_9 = ( 1 )
dim as nsab.T10 v17_10 = ( 1 )
dim as nsab.T11 v17_11 = ( 1 )
dim as nsab.T12 v17_12 = ( 1 )
dim as nsab.T13 v17_13 = ( 1 )
dim as nsab.T14 v17_14 = ( 1 )
dim as nsab.T15 v17_15 = ( 1 )
dim as nsab.T16 v17_16 = ( 1 )
dim as nsab.T17 v17_17 = ( 1 )
dim as long r17 = nsab.f17( @v17_1, @v17_2, @v17_3, @v17_4, @v17_5, @v17_6, @v17_7, @v17_8, @v17_9, @v17_10, @v17_11, @v17_12, @v17_13, @v17_14, @v17_15, @v17_16, @v17_17, @v17_17 )
if( r17 <> 18 ) then
	print "f17 returned "; r17; ", expected 18"
	end 1
end if

dim as nsab.T1 v19_1 = ( 1 )
dim as nsab.T2 v19_2 = ( 1 )
dim as nsab.T3 v19_3 = ( 1 )
dim as nsab.T4 v19_4 = ( 1 )
dim as nsab.T5 v19_5 = ( 1 )
dim as nsab.T6 v19_6 = ( 1 )
dim as nsab.T7 v19_7 = ( 1 )
dim as nsab.T8 v19_8 = ( 1 )
dim as nsab.T9 v19_9 = ( 1 )
dim as nsab.T10 v19_10 = ( 1 )
dim as nsab.T11 v19_11 = ( 1 )
dim as nsab.T12 v19_12 = ( 1 )
dim as nsab.T13 v19_13 = ( 1 )
dim as nsab.T14 v19_14 = ( 1 )
dim as nsab.T15 v19_15 = ( 1 )
dim as nsab.T16 v19_16 = ( 1 )
dim as nsab.T17 v19_17 = ( 1 )
dim as nsab.T18 v19_18 = ( 1 )
dim as nsab.T19 v19_19 = ( 1 )
dim as long r19 = nsab.f19( @v19_1, @v19_2, @v19_3, @v19_4, @v19_5, @v19_6, @v19_7, @v19_8, @v19_9, @v19_10, @v19_11, @v19_12, @v19_13, @v19_14, @v19_15, @v19_16, @v19_17, @v19_18, @v19_19, @v19_19 )
if( r19 <> 20 ) then
	print "f19 returned "; r19; ", expected 20"
	end 1
end if

end 0
