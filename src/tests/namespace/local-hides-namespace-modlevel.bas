' TEST_MODE : COMPILE_ONLY_FAIL

'' A local may hide a namespace of the same name (local-hides-namespace.bas),
'' but a variable at module level, in the namespace's own scope, is still a
'' duplicate definition, as in C++.

namespace K
	dim shared as long v = 1
end namespace

dim shared as long k = 2
