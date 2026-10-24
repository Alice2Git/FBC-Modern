' TEST_MODE : COMPILE_ONLY_FAIL
/'
	Instantiating a generic puts its declaring namespace and that namespace's
	imports (here the non-explicit enum) on the search chain only for the
	replay.  Afterwards, at module level, the enum constant must be as hidden
	as before: unqualified CODE_A is not declared.
'/

namespace N
	enum Codes
		CODE_A = 7
	end enum

	function F( of T )( byval x as T ) as long
		return CODE_A + x
	end function
end namespace

print N.F( 1l )
print CODE_A
