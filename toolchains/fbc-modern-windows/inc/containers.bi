'' containers.bi -- the FreeBASIC standard containers (RFC-0004)
''
''     #include once "containers.bi"
''     using FB
''
''     dim names as Array( of string )
''     dim ages  as Map( of string, long )
''     dim seen  as Set( of long )
''     dim queue as LinkedList( of string )
''
'' Four containers, written in ordinary FreeBASIC on top of generics
'' (RFC-0001), the iterator protocol (RFC-0002) and FOR EACH (RFC-0003).  None of
'' them is built into the compiler and none gets special treatment from it: a
'' better one written by anybody else is on exactly equal footing.
''
''     Array( of T )           growable array, amortised O(1) append
''     Map( of K, V )          open-addressed hash map
''     Set( of T )             hash set
''     LinkedList( of T )      doubly-linked list
''
'' They live in NAMESPACE FB and nothing is added to the global namespace, so a
'' program that already defines its own Array, Map, Set or List is unaffected
'' until it says 'using FB'.  This file is not included by default.
''
'' The pieces can be included individually -- fb/array.bi, fb/map.bi, fb/set.bi,
'' fb/linkedlist.bi -- and fb/hash.bi is where a user type is made usable as a
'' Map key or a Set element.
''
'' Three things worth reading before use, each documented at the top of its own
'' file:
''
''   - Array indices are ZERO-BASED, breaking with 'dim arr(1 to 10)' tradition.
''   - Map's indexer m[ k ] INSERTS on a miss.  Use TryGet or Contains to read.
''   - Copy and assignment are DEEP for all four.  There is no move constructor
''     in the language, so pass them BYREF where it matters.

#pragma once

#include once "fb/hash.bi"
#include once "fb/array.bi"
#include once "fb/map.bi"
#include once "fb/set.bi"
#include once "fb/linkedlist.bi"
