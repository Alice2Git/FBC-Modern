' TEST_MODE : COMPILE_ONLY_FAIL

'' A generic is a template, not a type: it has no size, no fields and no layout,
'' so it cannot be extended without a type argument list.  Already reported
'' correctly by the FB_SYMBCLASS_GENERIC arm in cSymbolType; pinned here so the
'' inheritance work cannot quietly turn it into something worse.

type Box( of T )
	as T v
end type

type Bad extends Box
	as integer x
end type
