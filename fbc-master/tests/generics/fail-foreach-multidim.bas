' TEST_MODE : COMPILE_ONLY_FAIL

'' There is no defensible default traversal order for a 2-D array, and picking
'' one silently would be worse than refusing.

dim m(0 to 1, 0 to 1) as long

for each v in m
next
