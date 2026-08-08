# RFC-0003 — Clocks

Status: **draft** · Phase 3 · Depends on: [RFC-0001](RFC-0001-core-representation.md), [RFC-0002](RFC-0002-timespan.md)

Three clocks: wall, monotonic, CPU. This is the only phase that adds per-OS
files.

## 1. Why three

They answer different questions and are not substitutes.

| Clock | Answers | Can jump backwards | Use for |
|---|---|---|---|
| Wall | "what time is it" | **yes** — NTP, DST, user change | timestamps, display, logs |
| Monotonic | "how long since" | no | timing, timeouts, benchmarks |
| CPU | "how much work" | no | profiling |

FreeBASIC's `TIMER` is the wall clock. Every FB benchmark ever written is
therefore wrong across an NTP correction, and silently reports a negative or
hour-sized interval across a DST shift. Neither FB nor AfxNova has a monotonic
source at all — this RFC closes the cheapest high-value gap in
[ranked-gaps.md](ranked-gaps.md).

## 2. Wall clock

> **Phase 3 amendments.** `Clock` and `CpuClock` are `namespace`s, not `type`s
> — FreeBASIC rejects a `TYPE` with no data members, and the call syntax
> `Clock.UtcNow( )` is identical either way. `Stopwatch` stays a `type` because
> it carries state. `Stop` is a FreeBASIC statement keyword, so the method is
> `Stop_`. `LocalOffsetAt` is deferred to RFC-0007; phase 3 ships only
> `fb_DtClockLocalOffsetNow`, which is all `Clock.Now( )` needs.

```freebasic
namespace Clock
  declare function UtcNow    ( ) as Instant
  declare function Now       ( ) as DateTime   ' local, offset filled in
  declare function Today     ( ) as LocalDate  ' local
  declare function TimeOfDay ( ) as LocalTime  ' local
  declare function Resolution( ) as TimeSpan   ' actual granularity
end namespace
```

`Now` returns a `DateTime` whose `m_offset` is the OS local offset **for that
instant** (not for right now — they differ for a value produced during a DST
transition second). `UtcNow` returns an `Instant`, which by RFC-0001 §2.2 has no
offset.

Backends:

| | Windows | Linux |
|---|---|---|
| Source | `GetSystemTimePreciseAsFileTime` | `clock_gettime( CLOCK_REALTIME )` |
| Fallback | `GetSystemTimeAsFileTime` | `gettimeofday` |
| Native unit | 100 ns since 1601 | s + ns since 1970 |
| Conversion | `+ DT_TICKS_TO_FILETIME` | `* 10^7 + ns/100 + DT_TICKS_TO_UNIX_EPOCH` |

`GetSystemTimePreciseAsFileTime` is Windows 8 / Server 2012 and later. It is
resolved once via `GetProcAddress` on `kernel32`, cached in a `static`, and
falls back to `GetSystemTimeAsFileTime` (≈15.6 ms granularity) when absent. The
fallback is a real functional difference, so `Resolution()` exists to report it
rather than have callers guess.

Note the Windows source is *already* in this library's unit — no scaling, no
rounding, no precision lost. That is the payoff from RFC-0001's choice of epoch
and tick size.

## 3. `Stopwatch` — the monotonic clock

```freebasic
type Stopwatch
  declare constructor( )                    ' created stopped, elapsed zero
  declare static function StartNew( ) as Stopwatch

  declare sub Start   ( )                   ' resume; no-op if running
  declare sub Stop_   ( )                   ' no-op if stopped; STOP is a keyword
  declare sub Reset   ( )                   ' stop and zero
  declare sub Restart ( )                   ' zero and start

  declare property IsRunning( ) as boolean
  declare property Elapsed  ( ) as TimeSpan
  declare property ElapsedMilliseconds( ) as longint
  declare property ElapsedTicks( ) as longint          ' library ticks, 100 ns

  declare static function Frequency( ) as longint      ' raw counts per second
  declare static function GetTimestamp( ) as longint   ' raw counter
  declare static function IsHighResolution( ) as boolean
end type
```

Backends:

| | Windows | Linux |
|---|---|---|
| Counter | `QueryPerformanceCounter` | `clock_gettime( CLOCK_MONOTONIC )` |
| Frequency | `QueryPerformanceFrequency` (cached once) | `10^9` (fixed) |

`CLOCK_MONOTONIC` rather than `CLOCK_MONOTONIC_RAW`: the former is slewed but
never stepped, which is what a stopwatch wants, and it is the one that is cheap
via vDSO. On Windows, `QPC` has been reliable and TSC-invariant-backed since
Windows 7 / Server 2008 R2; the pre-Vista multi-core skew problems do not apply
to any platform this compiler targets.

**Accumulate, do not recompute.** `Stop_` adds the running segment to an
accumulator; `Elapsed` while running returns accumulator + current segment. This
makes start/stop/start correct without special cases, and it is why `Elapsed` is
a property rather than being computed from two stored timestamps.

**Scaling.** Raw counts convert to library ticks as
`counts * 10^7 / Frequency`. Computed in that order with a 128-bit intermediate
where available (`__int128` on gcc; `Int64x64To128`/`_umul128` on MSVC-family)
so a long-running stopwatch does not overflow: at a 10 MHz `QPC` frequency,
`counts * 10^7` overflows `int64` after about 25.6 hours, which is well inside
what a real program will do. This is the one place in the library where a
silent-wrong-answer bug is easy to write, and the test in §5 targets it
specifically.

## 4. CPU time

```freebasic
namespace CpuClock
  declare function ProcessTime( ) as TimeSpan   ' user + kernel, this process
  declare function ProcessUserTime( ) as TimeSpan
  declare function ProcessKernelTime( ) as TimeSpan
  declare function ThreadTime( ) as TimeSpan    ' user + kernel, this thread
  declare function IsSupported( ) as boolean
end namespace
```

| | Windows | Linux |
|---|---|---|
| Process | `GetProcessTimes` (user + kernel `FILETIME`) | `clock_gettime( CLOCK_PROCESS_CPUTIME_ID )` |
| Thread | `GetThreadTimes` | `clock_gettime( CLOCK_THREAD_CPUTIME_ID )` |
| Split user/kernel | yes | **no** — via `getrusage( RUSAGE_SELF )` |

Linux's `CLOCK_PROCESS_CPUTIME_ID` gives a combined total only, so
`ProcessUserTime` / `ProcessKernelTime` there come from `getrusage`, which has
microsecond resolution rather than nanosecond. `ThreadTime` on Linux is the
combined figure; the split is not available per-thread and those two calls
return `Invalid` for threads. `IsSupported` reports availability rather than
having the calls lie.

## 5. Tests

Suite `fbc_tests.chrono.clocks`. Clock tests cannot assert exact values, so
they assert *invariants*. Each is chosen to fail on a real implementation bug.

**Wall clock**
- `UtcNow` twice in succession: non-decreasing, and the second is within one
  second of the first.
- `UtcNow` is within 24 h of a hardcoded build-era timestamp — catches an epoch
  constant off by a century, which is the classic failure here and would
  otherwise pass every relative test.
- **`Now( ).ToInstant( )` vs `UtcNow` does NOT catch an offset sign error** —
  `ToInstant` subtracts the very offset `FromInstant` added, so the two cancel
  and the round trip succeeds whichever way the sign points. It is still worth
  asserting (it catches a *magnitude* error in one of the two), but the sign
  needs an independent source of local time: compare the local **wall reading**
  against `datetime.bi`'s own `Now( )`, which reaches the OS by a separate path.
  A flipped sign puts the two 2 × offset apart. Verified by mutation: flipping
  the sign fails 3 assertions with this test, and 0 without it.
- `Today` equals `Now.GetDate()`.
- `Resolution` is positive and no worse than 20 ms.

**Stopwatch**
- Never negative, never decreasing while running.
- Stopped: `Elapsed` is stable across repeated reads.
- Start/Stop/Start accumulates: two 50 ms segments read as ≥ 90 ms, not ≥ 40 ms
  (catches the recompute-from-timestamps bug) and not ≥ 190 ms.
- `Reset` zeroes and stops; `Restart` zeroes and runs.
- `Stop` on a stopped watch and `Start` on a running one are no-ops.
- Against `Clock.UtcNow` over a ~200 ms sleep: agree within 50 ms. Loose on
  purpose — this is a sanity check on the frequency scaling, not a precision
  claim.
- **Scaling overflow**: call the raw conversion directly with a synthetic count
  representing 24 h — and a week — at 10 MHz, asserting exact tick equality.
  A pure-function test with no timing in it, and the only one that catches the
  `counts * 10^7` overflow. Note the non-`__int128` fallback path must be an
  *exact* split-multiply (whole seconds + remainder), not an approximation, so
  that both branches are correct and the choice between them is invisible.
- `Frequency` > 0; `GetTimestamp` non-decreasing over 1000 calls.

**CPU time**
- Non-decreasing across a busy loop, and strictly increasing across a loop long
  enough to consume measurable CPU. **A fixed-size loop is not good enough**:
  `GetProcessTimes` has a ~15.6 ms granularity (the scheduler tick), so a loop
  that finishes inside one tick leaves the value unchanged and a strict
  "greater than" fails intermittently. This was a genuinely flaky test — it
  failed about one run in three under `gas64`, which optimises the loop enough
  to slip under a tick, and it only surfaced when the same binary was run
  repeatedly. Burn CPU in a loop *until the clock advances*, with a wall-clock
  escape so a broken clock still fails rather than hanging.
- `ProcessTime` ≥ `ThreadTime` for a single-threaded program.
- Where the split is supported, `User + Kernel` equals `ProcessTime`.
- A sleep advances the wall clock but **not** the CPU clock by a comparable
  amount — the test that distinguishes a real CPU clock from a wall clock
  wearing its name.

All of the above on both platforms and both backends. Timing-sensitive
assertions use generous margins; a flaky clock test is worse than no clock test,
and every threshold above is chosen so that a correct implementation passes on a
loaded machine while a wrong one still fails.
