# Ranked gaps

The gaps from [comparison-matrix.md](comparison-matrix.md), re-ordered by
**value ÷ cost**. Value = how often a real FB program needs it × how badly it is
served today. Cost = implementation effort including tests.

This order drives the phase order in [README.md](README.md). Rank is not a
priority label to argue about later — it is the build sequence, and each rank
depends only on ranks above it.

| # | Gap | Value | Cost | RFC | Phase |
|---|---|---|---|---|---|
| 1 | Core instant type with 100 ns precision | critical | high | 0001 | 1–2 |
| 2 | `TimeSpan` duration type | critical | low | 0002 | 2 |
| 3 | ISO 8601 / RFC 3339 round-trip | critical | med | 0005 | 5 |
| 4 | Explicit UTC vs local, carried offset | high | med | 0001, 0007 | 2, 7 |
| 5 | Monotonic `Stopwatch` | high | **very low** | 0003 | 3 |
| 6 | Custom pattern format/parse | high | high | 0006 | 6 |
| 7 | Calendar-aware `AddMonths`/`AddYears` | high | low | 0004 | 4 |
| 8 | Calendar utilities (ISO week, leap, …) | med | **very low** | 0004 | 4 |
| 9 | `LocalDate` / `LocalTime` types | med | low | 0001 | 2 |
| 10 | OS-locale long/short formatting | med | med | 0007 | 7 |
| 11 | Interop converters | med | low | 0007 | 7 |
| 12 | Process/thread CPU time | low | very low | 0003 | 3 |

## Notes on the ranking

**#1 before everything.** Nothing else can be specified until the tick model,
the range, and the overflow rules are fixed. High cost, but it is not optional
and it is not divisible.

**#2 is cheap and unblocks #1's ergonomics.** `TimeSpan` is a single `int64`
with operators. It ships in the same phase as the core types because
`DateTime - DateTime` has nothing to return without it.

**#3 outranks the pattern formatter (#6)** even though both are "formatting".
ISO 8601 is a *fixed, small, unambiguous* grammar — one weekend of work — and it
is what JSON, HTTP, SQL, and every web API actually speak. The general pattern
engine is five times the work for a fraction of the interop value. Ship ISO
first; some programs will never need anything else.

**#5 is the best value on the board.** A monotonic stopwatch is roughly 60 lines
of C across two platform files, and it is the *only* correct way to time
anything. FB's `TIMER` reads the wall clock, so a benchmark straddling an NTP
correction or a DST shift silently reports nonsense. Neither FB nor AfxNova has
this. Rank 5 only because it depends on the tick type from #1.

**#8 is nearly free.** `fb_hGetWeekOfYear`, `fb_hGetWeeksOfYear`,
`fb_hGetDayOfYear`, `fb_hTimeLeap`, `fb_hTimeDaysInMonth` already exist and are
already correct in `src/src/rtlib/time_week.c` and `time_core.c`. They are just
not reachable from FB. The work is re-expressing them against the tick model and
writing the tests they never had.

**#9 is ranked below #7 despite being "core"** because a `DateTime` with a
zeroed time-of-day covers most of the need, and the type-safety win only pays off
in code that already uses the new API. It ships in phase 2 anyway — it costs
almost nothing once `DateTime` exists — but nothing above it waits on it.

**#10 is deliberately last of the formatting work** and is the one item whose
tests cannot assert exact strings, because the output is whatever the machine's
locale says. That is an honest limitation, recorded in RFC-0007, and it is a
reason to rank it *below* the two deterministic formatters, not above them.

**#12 is included only because it is trivial** once #5's clock plumbing exists —
the same two platform files, three more functions.

## Deliberately not ranked

These were considered and excluded; see [rationale.md](rationale.md) for the
reasoning.

- IANA tzdb / named zones / historical DST rules
- Leap seconds
- Non-Gregorian calendars
- Extending the legacy lenient parser (`fb_hDateParse`)
- Any change to `inc/datetime.bi` or the existing `time_*.c`
