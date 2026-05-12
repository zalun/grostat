## Context

Grostat collects inverter readings every 5 minutes via a launchd agent running 6:00–20:00 (`Sources/grostat/Commands/CollectCommand.swift` invoked on schedule). When the machine is off or the agent is broken, readings are silently missed. The existing `query-historical-data` command (`Sources/grostat/Commands/QueryHistoricalDataCommand.swift`) iterates a `--from / --to` range, calls `GrowattClient.fetchHistoricalData(date:)` once per day, and inserts readings whose `timestamp` isn't already in the database. The Growatt API caps historical queries at ~95 days back.

The proposal asks for a smarter, interactive flow: detect incomplete days, present them in a TUI, fetch only what the user confirms.

This is a non-trivial change because it introduces a TUI primitive (no existing terminal interactivity in the codebase) and shares fetch logic across two commands. A design doc is warranted.

## Goals / Non-Goals

**Goals:**

- Single new subcommand `grostat backfill` covering both gap-fill and history-extension flows.
- Detection algorithm is one SQL pass plus light Swift logic — no rolling windows, no per-day expected-count tables.
- TUI is self-contained, no new SPM dependencies, no third-party terminal libraries.
- Backfill is idempotent and non-destructive: re-running it never modifies existing rows or recomputes historical alerts.
- Share the per-day fetch routine between `query-historical-data` and `backfill` so throttling, dedupe, and error handling stay in one place.

**Non-Goals:**

- Sub-day fetch granularity. The Growatt historical API is per-day; partial-day fetches are not possible.
- Recomputing alert values for existing rows under new thresholds (out of scope; future work could add `--recompute-alerts`).
- Detecting gaps outside the 95-day API window (we can't backfill them anyway).
- Modifying the launchd schedule or making the collector itself more resilient.
- TUI features beyond a single-list checkbox selector (no scrolling beyond terminal height in v1 — list of incomplete days within 95 days is naturally bounded at ~95 entries).

## Decisions

### Detection signal: per-day count vs. per-month max

Chosen: count per day, compared against the maximum daily count within the same `YYYY-MM`, default threshold 70%.

Alternatives considered:

- **Inter-row delta within a day** (gap = consecutive timestamps > N minutes apart in the daytime window). More precise visualization ("missing 09:35 → 14:20") but functionally equivalent since the API is per-day. Adds a daytime-window heuristic and seasonal complexity (sunrise/sunset varies). Rejected: more code, no behavioural benefit.
- **Rolling N-day median of counts.** Self-calibrating to current-season production but more complex than month-max. Rejected: month-max is one extra SQL column and gives the same effect in practice.
- **Fixed daily threshold** (e.g., < 50 readings = gap). Rejected: winter days have fewer non-zero readings than summer days (after issue #4 lands), so a fixed number flags every winter day in a summer-trained dataset and vice versa.

Two implementation details:

- The "expected" baseline is `MAX(daily_count) GROUP BY strftime('%Y-%m', timestamp)`. This is the brightest day in that month — robust against the seasonal variation we care about, simple to compute.
- `count == 0` is special-cased as `missing` so it shows distinctly from `partial`, even when monthMax is also 0 (which would otherwise give a divide-by-zero / NaN ratio).

Threshold is configurable via `--threshold` (0.0–1.0) for the rare case the default is too noisy or too loose. Default 0.7 is a guess; we can tune after dogfooding.

### TUI: hand-rolled termios vs. dependency

Chosen: hand-rolled raw-mode terminal handler in Swift, using `Darwin.termios` and ANSI escape sequences.

Alternatives considered:

- **ConsoleKit / swift-cli-utility / similar SPM packages.** None mature enough or worth the maintenance overhead for a single screen of UI.
- **Shell out to `fzf`.** Adds an external runtime dependency we'd have to detect and instruct users to install. Rejected: violates "single binary" property of the CLI.
- **Number list + comma-separated input** (`Select [1,3,5]: `). Lower friction to build but uglier UX, and user explicitly asked for a real TUI. Rejected on user preference.

Shape of the TUI module (`Sources/grostat/TUI.swift`):

```
┌─────────────────────────────────────────────────────────────┐
│ TUI.swift — minimal raw-mode terminal helper                │
│                                                             │
│  enableRawMode()   — tcgetattr + tcsetattr (save & switch)  │
│  restoreTerminal() — restore saved termios                  │
│  readKey() -> Key  — single-byte + ESC[A/B/C/D parsing      │
│                                                             │
│  installSignalHandlers()                                    │
│    SIGINT, SIGTERM, SIGHUP → restore() then exit            │
│    Also wires `atexit()` for normal exit paths              │
│                                                             │
│  enum Key { up, down, space, enter, char(Character),        │
│             ctrlC, ctrlD, escape, unknown }                 │
│                                                             │
│  func selectMany<T>(items: [T],                             │
│                    render: (T, Bool, Bool) -> String,       │
│                    footer: ([T]) -> String) -> [T]?         │
│    Returns nil on quit/abort, [] on enter with none chosen  │
└─────────────────────────────────────────────────────────────┘
```

Rendering strategy: redraw the whole list on each keystroke, using `\x1b[H` (home) + `\x1b[J` (clear-to-end). The list is short (≤ ~95 items + 1 extension row), so flicker is irrelevant and we avoid cursor-position bookkeeping.

Signal handling is the trap: terminal must be restored even if the process is killed. We register `SIGINT`, `SIGTERM`, `SIGHUP` handlers that call `restoreTerminal()` and re-raise the signal. Also `atexit()` for normal termination paths.

### Fetch logic: extract, don't duplicate

Chosen: extract the per-day fetch loop from `QueryHistoricalDataCommand` into a shared helper `HistoricalFetcher` (likely a new file `Sources/grostat/HistoricalFetcher.swift`, or hung off `API.swift` if it stays small).

Shape:

```swift
struct HistoricalFetcher {
    let client: GrowattClient
    let db: Database
    let alerts: AlertChecker

    /// Fetches the given days sequentially with a 60s throttle between calls.
    /// Returns (inserted, skipped, failedDays).
    func fetchDays(_ dates: [String],
                   progress: (Int, Int, String) -> Void) -> FetchSummary
}
```

`QueryHistoricalDataCommand` becomes a thin wrapper that builds the date range and calls `fetchDays`. `BackfillCommand` builds the date list from the gap detection result and calls the same function. Throttling, dedupe-on-`hasTimestamp`, error-then-wait-60s, and the per-day inserted/skipped accounting all live in one place.

### Database queries

Two new read-only queries on `Database`:

- `countsByDay(from: String, to: String) -> [(day: String, count: Int)]` — returns one row per day in the range that has at least one reading. Days with zero readings are inferred by the caller iterating the date range and treating absent days as `count: 0`.
- `monthMaxes(from: String, to: String) -> [String: Int]` — returns `YYYY-MM → max daily count` for months overlapping the range.

`getDateRange()` already gives `MIN(timestamp), MAX(timestamp)` which we'll use for the history-extension logic.

All three are pure SELECT queries; no schema changes.

### Insert semantics: confirm "insert missing only"

The existing `hasTimestamp(ts)` guard in `QueryHistoricalDataCommand.swift:105` already implements the desired semantics. `backfill` reuses it via the shared `HistoricalFetcher`. No `INSERT OR REPLACE`, no delete-then-insert. This preserves historical `alert` column values (computed from whatever config was active when the row was first inserted) and avoids any chance of data loss if a refetch returns less data than was previously stored.

Trade-off accepted: if the user changes alert thresholds, backfilled days will have a mix of old-threshold alerts (existing rows) and new-threshold alerts (newly inserted rows). Documented; we can revisit with a `--recompute-alerts` flag later.

## Risks / Trade-offs

- **TUI leaves terminal in raw mode if process is killed abnormally** → Signal handlers for `SIGINT`/`SIGTERM`/`SIGHUP` plus `atexit()`. Worst case (SIGKILL, panic), user runs `stty sane`. Document this in `--help`.

- **Per-month max baseline is misleading for the current month** if the month is still in progress and no full day has accumulated yet → Affects only the in-progress month. Acceptable: backfill is run after-the-fact, and a freshly-installed user with one day of data will see no partial days flagged (only "missing" if any), which is reasonable behaviour.

- **Fetching the API max (95 days) with the 60s throttle takes ~95 minutes** → That's a known property of the Growatt API, not new. The TUI footer surfaces the time estimate before the user commits.

- **`--threshold 0.7` is a guess** → Exposing the flag lets us tune without a code change. If we find the right value over time, change the default.

- **Refactoring `QueryHistoricalDataCommand`** could regress its existing behavior → Mitigated by keeping the existing command's `run()` as the thin caller and lifting only the inner loop. Manual test: run `grostat query-historical-data --dry-run` against a known range before and after refactor.

## Open Questions

- Should `backfill` ever offer to fetch the *current* day (i.e., partial today)? The current day is always going to look partial because it hasn't finished. Lean toward: exclude `today` from the gap list to avoid noise. Confirm during implementation.

- TUI on a very narrow terminal — do we truncate long lines or let them wrap? Lean toward truncate with ellipsis; gap rows are short anyway.

- After fetch completes, should we re-run detection and show what's still incomplete (so the user sees the result)? Nice-to-have, not v1.
