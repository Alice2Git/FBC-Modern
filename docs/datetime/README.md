# Modern date/time for FreeBASIC

FreeBASIC's date/time surface is the VB6 model: serial `double` dates, second
resolution, no timezone concept, no duration type, no ISO 8601, no monotonic
clock. This directory specifies and documents a replacement that ships
**alongside** it.

Nothing here changes `inc/datetime.bi`, `inc/vbcompat.bi`, `FORMAT`, or any
existing `time_*.c`. The legacy surface stays bit-for-bit compatible, and the
two meet at `FromSerial` / `Serial` so a program can migrate one function at a
time. **No compiler change was made** — this is a library.

```freebasic
#include once "fb/chrono.bi"
using FB

dim as DateTime d = DateTime( 2025, 3, 4, 14, 30, 5, 0 ).WithOffset( 330 )
print d.ToIsoString( )                       '' 2025-03-04T14:30:05+05:30
print d.ToString( "dddd, dd MMMM yyyy" )     '' Tuesday, 04 March 2025
print ( Clock.UtcNow( ) - d.ToInstant( ) ).TotalDays
```

## Start here

| | |
|---|---|
| **Using it** | [migration.md](migration.md) — every `datetime.bi` and AfxNova member mapped to its equivalent |
| **Seeing it** | [examples/tour.bas](examples/tour.bas), [examples/migrating.bas](examples/migrating.bas) — both compile and run |
| **Why it is shaped this way** | [rationale.md](rationale.md) |
| **What it was measured against** | [comparison-matrix.md](comparison-matrix.md), [ranked-gaps.md](ranked-gaps.md) |

## The specification

| RFC | Scope |
|---|---|
| [RFC-0001](RFC-0001-core-representation.md) | Tick model, `DateTime`, `LocalDate`, `LocalTime`, `Instant`, the `Invalid` sentinel |
| [RFC-0002](RFC-0002-timespan.md) | `TimeSpan` |
| [RFC-0003](RFC-0003-clocks.md) | Wall clock, `Stopwatch`, CPU time |
| [RFC-0004](RFC-0004-calendar.md) | Calendar arithmetic and utilities |
| [RFC-0005](RFC-0005-iso8601.md) | ISO 8601 / RFC 3339 |
| [RFC-0006](RFC-0006-patterns.md) | Custom pattern format and parse |
| [RFC-0007](RFC-0007-zones-locale-interop.md) | OS-native offsets, locale formatting, interop, `USTRING` |

## Design in one table

| | |
|---|---|
| Shape | Library only. C in `src/src/rtlib`, FB types in `src/inc/fb/chrono.bi`. **No compiler changes.** |
| Platforms | Windows and Linux. **Linux is written but unverified — see Status.** |
| Representation | `int64` ticks of 100 ns since `0001-01-01T00:00:00`. Range year 1 – 9999. |
| Semantics | Immutable value types. `AddDays` returns a new value. |
| Timezones | OS-native only: UTC, the OS local zone, fixed offsets. No IANA tzdb. |
| Errors | `TryParse` + an `Invalid` sentinel. No `err()`, no exceptions, **arithmetic never wraps**. |
| Strings | `STRING` (UTF-8) core; `USTRING` overloads layered on top. |

## What shipped

| File | Role |
|---|---|
| `src/inc/fb/chrono.bi` | The whole FB surface — 9 types/namespaces, ~228 members |
| `src/src/rtlib/fb_chrono.h` | C declarations and the tick constants |
| `src/src/rtlib/dt_core.c` | Civil↔tick kernel, calendar primitives, count scaling |
| `src/src/rtlib/dt_iso.c` | ISO 8601 / RFC 3339 emit and strict parse |
| `src/src/rtlib/dt_pattern.c` | Pattern formatter and strict parser, invariant English |
| `src/src/rtlib/{win32,unix}/dt_clock.c` | Wall, monotonic and CPU clocks |
| `src/src/rtlib/{win32,unix}/dt_zone.c` | Offsets, DST, locale formatting |
| `src/tests/chrono/*.bas` | 8 fbcunit suites |
| `tests/dt_core_test.c` | Standalone C harness for the kernel sweep |

## Building and testing

The tick kernel is pure C with a standalone harness, run directly rather than
through fbcunit — a 3.65-million-iteration sweep has no sensible home in the
`.bas` suite. From the repo root:

```bash
gcc -O2 -Wall -I src/src/rtlib tests/dt_core_test.c src/src/rtlib/dt_core.c src/src/rtlib/time_core.c -o tests/dt_core_test.exe && ./tests/dt_core_test.exe
```

The FB suites, per `tests/BASELINE.md`:

```bash
cd src/tests && make unit-tests FBC="C:/dev/FBC-Modern/src/bin/fbc.exe -i C:/dev/FBC-Modern/src/inc -p C:/dev/utils/mingw64/lib"
```

**Environment note:** `make rtlib` on this machine fails in `thread_call.c` with
`fatal error: ffi.h: No such file or directory` — libffi's headers are not
installed. Pre-existing and unrelated to chrono. Use the makefile's own flag:

```bash
make rtlib CFLAGS="-DDISABLE_FFI"
```

That disables `ThreadCall` only. The 11 `fbc_tests.threads.threadcall_` failures
it causes are the documented baseline; a 12th failure anywhere is a regression.

### Four traps this work hit

**A per-OS `.c` must not share its base name with one in `src/rtlib/`.** The
makefile maps every `RTLIB_DIRS` entry through
`$(patsubst $(i)/%.c,$(objdir)/%.o,…)` and then `$(sort …)`, so
`rtlib/dt_clock.c` and `rtlib/win32/dt_clock.c` both map to
`obj/win64/dt_clock.o` and `sort` silently keeps one. No warning — the platform
backend just vanishes from the link. Hence the pure scaling helper lives in
`dt_core.c`, and `dt_clock.c`/`dt_zone.c` exist *only* under `win32/` and
`unix/`. The existing tree follows the same rule (`time_timer.c`).

**Adding a test FILE needs `unit-tests.inc` regenerated, and `make clean-tests`
does not do it.** That file is the generated list of every `.bas` containing an
fbcunit include, rebuilt only when `dirlist.mk` is *newer*. A new test file in an
existing directory is silently ignored — the suite builds, passes, and never
runs it. Use `rm unit-tests.inc` or a full `make clean`. (`tests/BASELINE.md`
says `make clean-tests` suffices; it does not.)

**`make unit-tests` does not track `.bi` dependencies.** Editing a header will
not rebuild the test objects that include it. Any header change needs
`rm tests/chrono/*.o`, or you are testing the old build — which silently
invalidates mutation testing in particular.

**Assert your test generator's range.** Every fixed-seed sweep originally drew
its tick as `clngint( ( seed shr 11 ) mod culngint( DT_MAX_TICKS ) )`. The shift
leaves 53 bits, and `2^53` is *smaller* than `DT_MAX_TICKS` (3.16e18), so the
`mod` was a no-op and every "random" value landed in **years 1–29**. Five suites
were affected and coverage claims were overstated for four phases before it was
caught. The correct form is `clngint( seed mod culngint( DT_MAX_TICKS ) )`.
Re-running found no implementation bugs — the layers were right, the sweeps were
just tiny.

## Status

Phase 0 (the RFCs) is the contract. A later phase may not silently diverge from
an RFC — the rule was to amend the RFC in the same change that alters behaviour,
and every divergence was handled that way.

| Phase | Scope | State |
|---|---|---|
| 0 | The RFCs, matrix, ranked gaps | **done** |
| 1 | C tick kernel | **done** — 23.3 M assertions |
| 2 | `TimeSpan`, `DateTime`, `Instant`, `LocalDate`, `LocalTime` | **done** |
| 3 | Clocks | **done** |
| 4 | Calendar arithmetic and utilities | **done** |
| 5 | ISO 8601 / RFC 3339 | **done** |
| 6 | Custom patterns | **done** |
| 7 | Offsets, locale formatting, interop | **done** |
| 8 | `USTRING` overloads | **done** |
| 9 | Migration guide, examples, docs | **done** |

### Verified

- **1,594,943 assertions, 11 failures** — all 11 are the documented
  `threadcall_` baseline. Identical under the default backend and `GEN=gas64`,
  and stable across repeated runs of the same binary.
- The C kernel's own harness: **23,304,597 checks, 0 failures**, including an
  exhaustive civil↔tick round trip over every one of the 3,652,059 days in range
  and an exhaustive ISO-week structural check over the same.
- `errors` and `warnings` golden-diff suites clean.
- Both example programs compile and run.
- **~40 seeded mutants killed** across the eight suites. Three survived and are
  documented as such: two provably equivalent mutants, and one property (the
  dynamic-vs-static Windows zone API) that is not portably testable and is
  verified by inspection instead — RFC-0007 §6 records the observed values.

### Not verified

- **Linux.** `unix/dt_clock.c` and `unix/dt_zone.c` have never been compiled or
  run. This is the single largest gap in the work, and phase 7 is where the two
  platforms diverge most. Everything else in the library is portable C or FB
  that does not touch the OS.
- `log-tests` (the per-dialect compile-and-run suite) was not run.
- Locale-formatted output is asserted only by invariant — non-emptiness,
  ordering, distinctness, valid UTF-8. It is whatever the machine says, and
  RFC-0007 §3 states plainly that exact-string assertions there would be either
  locale-pinned or dishonest.

### Known limitations, by design

Leap seconds · non-Gregorian calendars · IANA tzdb, named zones and
DST-ambiguity policies · extending the legacy lenient parser. Each is argued in
[rationale.md](rationale.md). `AssumeLocal` inside a DST fall-back hour takes
the OS's answer, which is the strongest argument for a future tzdb phase.
