'' FOR EACH over a type that satisfies none of RFC-0002.
''
'' One case per file: the compiler stops at the first error in many situations,
'' and these cases interfere (see readme.txt).

#print === no GetIterator at all ===
type Plain
	as long v
end type

dim p as Plain

for each v in p
next
