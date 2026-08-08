# RFC-0002 — `TimeSpan`

Status: **draft** · Phase 2 · Depends on: [RFC-0001](RFC-0001-core-representation.md)

A duration. FreeBASIC currently has no way to *name* "three hours" — this is the
smallest RFC in the set and one of the two most valuable.

> **Naming note (phase 2).** `Abs` is a reserved FreeBASIC keyword, so the
> absolute-value method is spelled `Duration( )` — which is also what C# calls
> this exact operation. The type lives in `namespace FB`, as `FB.TimeSpan`.

## 1. Representation

```freebasic
type TimeSpan
  m_ticks as longint      ' signed; 100 ns units
end type
```

Signed, so a span can be negative — `earlier - later` is meaningful and is not an
error. Range is the full `int64`: ±10,675,199 days, roughly ±29,227 years, which
comfortably exceeds any difference two in-range `DateTime`s can produce.

`TimeSpan` has no `Invalid` state of its own. It reaches `Invalid` only by
absorption: an operation with an `Invalid` `DateTime` operand yields
`TimeSpan.Invalid`, encoded as `DT_INVALID_TICKS`, which is excluded from the
usable range for exactly this purpose.

This is a **fixed** duration — an exact count of ticks. It is not a calendar
period: "one month" is not a `TimeSpan`, because months are not a fixed length.
Calendar arithmetic lives in [RFC-0004](RFC-0004-calendar.md) as `AddMonths` /
`AddYears`, which take a plain `long`.

## 2. Construction

```freebasic
declare constructor( )                                   ' zero
declare constructor( byval ticks as longint )
declare constructor( byval h as long, byval mi as long, byval s as long )
declare constructor( byval d as long, byval h as long, byval mi as long, _
                     byval s as long, byval ms as long = 0 )

declare static function FromDays        ( byval v as double  ) as TimeSpan
declare static function FromHours       ( byval v as double  ) as TimeSpan
declare static function FromMinutes     ( byval v as double  ) as TimeSpan
declare static function FromSeconds     ( byval v as double  ) as TimeSpan
declare static function FromMilliseconds( byval v as double  ) as TimeSpan
declare static function FromMicroseconds( byval v as longint ) as TimeSpan
declare static function FromTicks       ( byval v as longint ) as TimeSpan

declare static property Zero( ) as TimeSpan
declare static property MinValue( ) as TimeSpan
declare static property MaxValue( ) as TimeSpan
declare static property Invalid( ) as TimeSpan
```

The `From*` factories take `double` so `TimeSpan.FromHours( 1.5 )` works. They
round **half away from zero** to the nearest tick. A `double` argument that is
NaN, infinite, or whose tick value exceeds the `int64` range yields `Invalid`.

`FromMicroseconds` and `FromTicks` take `longint` instead, because at those
magnitudes a `double` has already lost bits.

## 3. Totals versus components

The distinction that every duration API gets asked about, so it is spelled out:
**Total\*** returns the whole span expressed in that unit, fractional;
**component** returns the remainder-style piece of a broken-down rendering.

For a span of 1 day, 2 hours, 3 minutes:

| | value |
|---|---|
| `TotalHours` | `26.05` |
| `Hours` | `2` |
| `TotalMinutes` | `1563.0` |
| `Minutes` | `3` |
| `Days` | `1` |

```freebasic
declare property Ticks( ) as longint

declare property TotalDays        ( ) as double
declare property TotalHours       ( ) as double
declare property TotalMinutes     ( ) as double
declare property TotalSeconds     ( ) as double
declare property TotalMilliseconds( ) as double
declare property TotalMicroseconds( ) as longint

declare property Days        ( ) as long   ' signed
declare property Hours       ( ) as long   ' -23 .. 23
declare property Minutes     ( ) as long   ' -59 .. 59
declare property Seconds     ( ) as long   ' -59 .. 59
declare property Milliseconds( ) as long   ' -999 .. 999
declare property Microseconds( ) as long   ' -999999 .. 999999
```

Components of a negative span are **all negative**, matching C# `TimeSpan`. A
span of −1 h 30 m has `Hours = -1` and `Minutes = -30`, not `-1` and `+30`. This
keeps `Days*86400 + Hours*3600 + …` reconstructing the original for every span,
positive or negative, which is the property the tests assert.

## 4. Operations

```freebasic
declare property IsValid ( ) as boolean
declare property IsZero  ( ) as boolean
declare property IsNegative( ) as boolean

declare function Negate  ( ) as TimeSpan
declare function Duration( ) as TimeSpan   ' absolute value
declare function Add     ( byref o as TimeSpan ) as TimeSpan
declare function Subtract( byref o as TimeSpan ) as TimeSpan
declare function Multiply( byval f as double   ) as TimeSpan
declare function Divide  ( byval f as double   ) as TimeSpan
declare function DivideBy( byref o as TimeSpan ) as double     ' ratio
declare function CompareTo( byref o as TimeSpan ) as long      ' -1 / 0 / +1, or -2
```

Operators, as free `operator` declarations in the header:

| Operator | Signature |
|---|---|
| `+` | `TimeSpan + TimeSpan → TimeSpan` |
| `-` | `TimeSpan - TimeSpan → TimeSpan` |
| `-` (unary) | `-TimeSpan → TimeSpan` |
| `*` | `TimeSpan * double → TimeSpan`, `double * TimeSpan → TimeSpan` |
| `/` | `TimeSpan / double → TimeSpan` |
| `=` `<>` `<` `>` `<=` `>=` | `TimeSpan, TimeSpan → boolean` |

Cross-type operators live with the type they produce, in
[RFC-0004](RFC-0004-calendar.md): `DateTime + TimeSpan`, `DateTime - TimeSpan`,
`DateTime - DateTime → TimeSpan`, and the same three for `Instant`.

Rules:

- Every arithmetic operation that overflows `int64` yields `Invalid`. It does
  not wrap. Addition overflow is detected before it happens, not by inspecting
  the result.
- `Divide` by zero yields `Invalid`. `DivideBy` a zero span yields NaN.
- `Negate` of `MinValue` is **valid** and yields `MaxValue`. Because the
  `Invalid` sentinel occupies `LLONG_MIN`, `MinValue` is `LLONG_MIN + 1`, which
  negates cleanly. (An earlier draft of this RFC said otherwise; it assumed
  `MinValue` was `LLONG_MIN`.)
- `CompareTo` returns `-2`, not an ordering, when either operand is `Invalid`.
  `-2` rather than `0` so that "incomparable" can never be mistaken for "equal".
- Comparison with an `Invalid` operand is `false` on every operator, including
  `=`, per RFC-0001 §3 rule 4.

## 5. Formatting

`TimeSpan` renders as an ISO 8601 duration by default, and supports the
constant-format shorthands:

| Method | Output for 1 d 2 h 3 m 4.5 s |
|---|---|
| `ToString()` | `P1DT2H3M4.5S` |
| `ToIsoString()` | `P1DT2H3M4.5S` |
| `ToString( "c" )` | `1.02:03:04.5000000` — **deferred to phase 6** |
| `ToString( "g" )` | `1:2:03:04.5` — **deferred to phase 6** |

Phase 5 ships `ToString( )` with no argument, which is `ToIsoString( )`. The
`"c"` and `"g"` shorthands are constant-format patterns and belong with the rest
of the pattern engine in [RFC-0006](RFC-0006-patterns.md).

Negative spans are prefixed `-` (`-P1DT2H`), which is the ISO 8601 form.
Grammar and `TryParse` are specified in
[RFC-0005](RFC-0005-iso8601.md) §5 alongside the rest of ISO 8601, since they
share a lexer.

## 6. Tests

Suite `fbc_tests.chrono.spans` — *not* `.timespan`: with `using FB` in scope the
suite identifier `timespan` collides with the type name, and FreeBASIC is
case-insensitive.

- Every listed member gets at least one test.
- **Totals/components consistency**: for a table of spans covering positive,
  negative, zero, sub-tick-rounding, and both extremes,
  `Days*TICKS_PER_DAY + Hours*TICKS_PER_HOUR + … + Ticks-remainder` must
  reconstruct `Ticks` exactly.
- **Negative component signs**: assert `TimeSpan(0,-1,-30,0).Hours = -1` and
  `.Minutes = -30`.
- **Rounding**: `FromSeconds(0.00000005)` (half a tick) rounds away from zero;
  `FromMilliseconds(1.0/3.0)` matches the computed tick count exactly.
- **Overflow**: `MaxValue + FromTicks(1)`, `MinValue - FromTicks(1)`,
  `MaxValue * 2`, `Divide(0)` — all `Invalid`, none wrapped. Assert the result
  is *not* equal to the wrapped value, so a regression that reintroduces
  wrapping fails loudly. **Choose the input carefully:** `MaxValue + 1` wraps to
  exactly `LLONG_MIN`, which *is* the sentinel, so for that one input "wrapped"
  and "Invalid" are indistinguishable by value and the assertion is vacuous. Use
  `MaxValue + 2`, which wraps to `MinValue`.
- `Negate(MinValue)` = `MaxValue`, and `Duration(MinValue)` = `MaxValue`.
- **Non-finite input**: `FromHours(0.0/0.0)` and `FromHours(1.0/0.0)` →
  `Invalid`.
- **Comparison against `Invalid`** is `false` on all six operators.
- **Operator/method parity**: `a + b` and `a.Add(b)` agree for the whole table.
