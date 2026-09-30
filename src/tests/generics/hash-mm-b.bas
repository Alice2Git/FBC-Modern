'' Module B of hash-mm.bmk -- the same headers, a different key type, so a
'' second instantiation calls HashOf too.

#include once "fb/map.bi"
#include once "fb/set.bi"

function HashModuleB( ) as long
	dim as FB.Map( of long, string ) m
	m.Put( 7, "seven" )
	dim as FB.Set( of string ) s
	s.Add( "x" )
	s.Add( "y" )
	return m.Count( ) + s.Count( )
end function
