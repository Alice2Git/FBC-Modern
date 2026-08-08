# Rationale

Why this design and not the other ones. Each section records a decision that is
expensive to reverse later.

## Why a library, not language keywords

The compiler already knows five date/time intrinsics — `TIMER`, `TIME`, `DATE`,
`SETTIME`, `SETDATE`, registered in `src/src/compiler/rtl-system.bas`. Adding to
that table means new tokens in the lexer, new parse paths, dialect gating, and a
permanent expansion of the reserved-word set that breaks any existing program
using those identifiers.

The entire VB-compatible surface — `DateSerial`, `DateAdd`, `Now`, `Year`,
`DatePart` — is *already* just `declare … alias` lines in `inc/datetime.bi`.
That is the proven, zero-risk extension point in this codebase, and it is what
this work uses. **No file under `src/src/compiler/` is touched.**

## Why ticks of 100 ns since 0001-01-01

The three candidates:

| Model | Range | Precision | Size |
|---|---|---|---|
| ns since 1970 (Go, Rust) | 1678–2262 | 1 ns | 8 B |
| **100 ns since year 1 (.NET)** | **1–9999** | **100 ns** | **8 B** |
| seconds + nanos (C++, timespec) | unbounded | 1 ns | 12–16 B |

Nanoseconds-since-1970 was rejected on range: a library that cannot represent
1900 or 2300 is not a general date type, and FB users write business and
historical software.

The split representation was rejected on weight. Every operation becomes
two-field math with carry, every comparison is two comparisons, and the type
stops fitting in a register. Nanosecond precision buys nothing a desktop Win32
or Linux program can observe — neither OS clock resolves below ~100 ns anyway.

100 ns ticks since year 1 wins on all three axes at once. It is a single `int64`.
It spans every date anyone will ask for. And it converts to the two
representations FB must interoperate with by *addition of a constant*:

- Win32 `FILETIME` is 100 ns ticks since 1601-01-01 → subtract `504911232000000000`.
- Unix seconds → subtract the year-1-to-1970 tick constant, divide by `10^7`.

Same unit, no scaling, no rounding. That is not a coincidence — .NET chose it for
the same reason.

`int64` max is `9223372036854775807` ticks ≈ year 29228, so year 9999 is a
*policy* limit, not a representational one. It is enforced so that every value in
range has a well-formed ISO 8601 rendering with a four-digit year.

## Why immutable

Every modern design converged here: java.time, NodaTime, Temporal, Rust, Go.
The two that did not — Python's `datetime` is immutable but `struct tm` is not,
and AfxNova's `CPowerTime` is mutating — are the two with the aliasing hazard.

`CPowerTime.AddDays` mutates the receiver. Pass a `CPowerTime` `byref` to a
helper that adds a day for a local calculation, and the caller's value changes.
That is a real bug class, and it is the one FB's `byref`-by-default parameter
convention makes easiest to hit.

`dt = dt.AddDays(3)` is one extra assignment and cannot surprise anyone.

## Why OS-native timezones and not IANA tzdb

Full tzdb support means shipping and *maintaining* the zone database — it
changes several times a year, and a stale copy silently produces wrong local
times. It also means the ambiguity machinery: a local time during a DST
fall-back names two instants, and during a spring-forward gap names none, so
every local→instant conversion needs a documented resolution policy.

That is a project on its own, and it is not the project this is. The OS already
knows the user's zone and its DST rules, and keeps them current. `UTC`, `local`,
and explicit fixed offsets cover what a desktop application actually does.

The type design does not foreclose it: `DateTime` carries an offset, so a future
`ZonedDateTime` can be added without changing anything specified here.

## Why no leap seconds

Almost nothing supports them (only C++20's `utc_clock`). They require a table
that must be updated by decree. They make `b - a` for two instants
non-computable from the values alone. The universal choice is to pretend they do
not exist, and the universal choice is correct for this audience.

## Why not extend the lenient parser

`fb_hDateParse` guesses field order from locale and accepts a wide, undocumented
set of inputs. It is what `IsDate` and `DateValue` are built on, and it must keep
working exactly as it does for compatibility.

But leniency is the opposite of what interop needs. `03/04/2025` is March 4th or
April 3rd depending on where the machine is, and a parser that resolves that
silently is a data-corruption engine. The new API parses *strictly* — the caller
states the grammar (ISO, or an explicit pattern) and gets `false` from `TryParse`
if the input does not match it.

The legacy path stays. It is simply not built upon.

## Why `TryParse` and a sentinel instead of `err()`

FB's runtime-error mechanism is opt-in: `err()` must be checked, and a program
compiled without error checking never sees it. That makes silent-wrong-answer the
default failure mode for a date parse, which is the worst possible default.

`if DateTime.TryParse( s, dt ) then` cannot be ignored — the value is not usable
until the branch is taken. And an `Invalid` sentinel (`ticks = LLONG_MIN`) makes
every arithmetic overflow propagate visibly rather than wrapping, which is what
FB and AfxNova both do today.

Exceptions were not considered; FB does not have them in a form this could use.

## Why `STRING` first and `USTRING` after

The `STRING`/UTF-8 surface is what the rest of the rtlib speaks, so the C core
returns `char*` and needs no conversion layer for the deterministic formatters —
ISO 8601 and every pattern output are ASCII by construction.

`USTRING` matters only where output can contain non-ASCII text: OS-locale month
and day names. Those live in phase 7. Building the `USTRING` overloads in phase
8, against a frozen `STRING` surface, means writing each one once instead of
tracking a moving target.

## Why a `datetime2`-shaped parallel surface rather than fixing the old one

Because `inc/datetime.bi` is in every FreeBASIC program written in the last
twenty years, and its semantics — serial doubles, locale-guessing parses,
second resolution — are load-bearing for those programs. There is no
compatible way to add precision or a timezone concept to a `double`.

The two surfaces coexist. RFC-0007 specifies converters in both directions so a
program can migrate one function at a time.
