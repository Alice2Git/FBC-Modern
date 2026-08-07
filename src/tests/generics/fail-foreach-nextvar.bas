' TEST_MODE : COMPILE_ONLY_FAIL

'' NEXT may not name the loop variable.  In a FOR EACH the variable is the
'' element, not a counter, and it is scoped to the body -- naming it would
'' suggest it survives the loop.

dim a(0 to 1) as long

for each v in a
next v
