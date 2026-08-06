' TEST_MODE : COMPILE_ONLY_FAIL

'' A type with none of the protocol's members cannot be walked.  The message
'' names what is needed, because the failure mode of a structural protocol is a
'' near-miss rather than an obvious mistake.

type Plain
	as long v
end type

dim p as Plain

for each v in p
next
