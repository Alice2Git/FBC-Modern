' TEST_MODE : COMPILE_AND_RUN_OK

'' A generic whose body mentions itself.
''
'' Two things have to line up for this to work.  The instantiated struct is
'' created under an internal name, not the generic's, because symbStructBegin
'' publishes the name before the body is parsed -- naming it 'Node' would make
'' the self-reference bind to the half-built struct and the '( of T )' would
'' never be consumed.  And the in-progress cache entry hands back a FWDREF, so
'' the reference is legal behind a pointer and symbCheckFwdRef patches it once
'' the body completes.
''
'' The pointer must be usable, not merely declarable: dereferencing through it
'' is what proves the forward reference was actually resolved.

#define assert_(e) if (e) = 0 then fb_Assert(__FILE__, __LINE__, __FUNCTION__, #e)

type Node( of T )
	as T v
	as Node( of T ) ptr nxt
end type

	dim a as Node( of long )
	dim b as Node( of long )

	a.v = 1
	b.v = 2
	a.nxt = @b

	assert_( a.v = 1 )
	assert_( a.nxt->v = 2 )
	assert_( a.nxt->nxt = 0 )

	'' a second element type gets its own, unrelated, self-referential type
	dim s as Node( of string )
	dim s2 as Node( of string )
	s.v = "head"
	s2.v = "tail"
	s.nxt = @s2
	assert_( s.nxt->v = "tail" )
