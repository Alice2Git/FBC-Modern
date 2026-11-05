' TEST_MODE : COMPILE_ONLY_FAIL

'' A dynamic USTRING in static data cannot be initialized, as a dynamic STRING
'' cannot (error 87): it needs code to run.  It used to reach the backend and
'' fail there with invalid C (gcc) or garbage data (gas / gas64).

dim shared as ustring s = "x"
