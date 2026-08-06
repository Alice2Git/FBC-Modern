'' In a FOR EACH the variable is the element, not a counter, and it is scoped to
'' the loop body -- naming it after NEXT would suggest it survives the loop.

#print === next naming the loop variable ===
dim a(0 to 1) as long

for each v in a
next v
