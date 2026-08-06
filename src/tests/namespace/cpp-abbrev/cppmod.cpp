// Regression test for Itanium C++ ABI substitution (abbreviation) mangling
// at sequence ids past 'W'.
//
//   <substitution> ::= S <seq-id> _ | S_
//
// <seq-id> is (index - 1) in base 36 using the digits 0-9 then A-Z.
// fbc used to switch to a broken 2-digit form at index 34, emitting
// chr( idx \ 33 ) -- a raw control byte -- rather than a base-36 digit.
//
// Each trailing repeated parameter forces a back-reference to a high
// substitution index: f17 reaches index 34 (seq-id 'X'), f19 reaches
// index 38, the first genuinely 2-digit case (seq-id '11').
//
// g++ mangles these names; fbc must agree or the link fails.

namespace nsab
{
	struct T1 { int v; };
	struct T2 { int v; };
	struct T3 { int v; };
	struct T4 { int v; };
	struct T5 { int v; };
	struct T6 { int v; };
	struct T7 { int v; };
	struct T8 { int v; };
	struct T9 { int v; };
	struct T10 { int v; };
	struct T11 { int v; };
	struct T12 { int v; };
	struct T13 { int v; };
	struct T14 { int v; };
	struct T15 { int v; };
	struct T16 { int v; };
	struct T17 { int v; };
	struct T18 { int v; };
	struct T19 { int v; };

	int f17( T1 *p1, T2 *p2, T3 *p3, T4 *p4, T5 *p5, T6 *p6, T7 *p7, T8 *p8, T9 *p9, T10 *p10, T11 *p11, T12 *p12, T13 *p13, T14 *p14, T15 *p15, T16 *p16, T17 *p17, T17 *r )
	{
		return p1->v + p2->v + p3->v + p4->v + p5->v + p6->v + p7->v + p8->v + p9->v + p10->v + p11->v + p12->v + p13->v + p14->v + p15->v + p16->v + p17->v + r->v;
	}

	int f19( T1 *p1, T2 *p2, T3 *p3, T4 *p4, T5 *p5, T6 *p6, T7 *p7, T8 *p8, T9 *p9, T10 *p10, T11 *p11, T12 *p12, T13 *p13, T14 *p14, T15 *p15, T16 *p16, T17 *p17, T18 *p18, T19 *p19, T19 *r )
	{
		return p1->v + p2->v + p3->v + p4->v + p5->v + p6->v + p7->v + p8->v + p9->v + p10->v + p11->v + p12->v + p13->v + p14->v + p15->v + p16->v + p17->v + p18->v + p19->v + r->v;
	}

}
