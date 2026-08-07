'' A var-len STRING carries its own length; a fixed-length buffer does not, and
'' RFC-0003 5 wants a ZSTRING walked to its terminating NUL rather than to its
'' declared size -- a different loop, not a different bound.

#print === for each over a fixed-length string ===
dim as zstring * 8 z = "hi"

for each ch in z
next
