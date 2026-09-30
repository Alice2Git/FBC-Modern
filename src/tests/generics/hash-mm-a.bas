'' Module A of hash-mm.bmk.  Includes fb/map.bi and fb/set.bi -- and with them
'' every FB.HashOf overload -- exactly as module B and the driver do.

#include once "fb/map.bi"
#include once "fb/set.bi"

function HashModuleA( ) as long
	dim as FB.Map( of string, long ) m
	m.Put( "a", 1 )
	m.Put( "b", 2 )
	dim as FB.Set( of long ) s
	s.Add( 10 )
	return m.Count( ) + s.Count( )
end function
