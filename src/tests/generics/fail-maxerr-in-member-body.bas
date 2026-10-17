' TEST_MODE : COMPILE_ONLY_FAIL
/'
	Reaching -maxerr inside a replayed generic member body must still end the
	compile.  The replay stops in mid-procedure, so that procedure is never
	closed; replaying the next owed body anyway nested the instantiation's
	namespace a second time, which made the nested-hash list a cycle.  fbc then
	printed "Too many errors, exiting" and never exited.

	Two member bodies are enough: the first reaches the limit, the second must
	not be replayed.  If this regresses, the suite hangs on this file.
'/
#cmdline "-maxerr 1"

type NoCopy
	private:
		declare operator let( byref rhs as const NoCopy )
	public:
		as long x
end type

type Box( of T )
	as T items( 0 to 1 )
	declare sub First( )
	declare sub Second( )
end type

sub Box( of T ).First( )
	for i as long = 0 to 0
		this.items( i ) = this.items( i + 1 )
	next
end sub

sub Box( of T ).Second( )
	this.items( 1 ) = this.items( 0 )
end sub

dim b as Box( of NoCopy )
