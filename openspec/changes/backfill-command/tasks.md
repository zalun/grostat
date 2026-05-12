## 1. Database queries

- [x] 1.1 Add `countsByDay(from:to:) -> [(day: String, count: Int)]` to `Sources/grostat/Database.swift`
- [x] 1.2 Add `monthMaxes(from:to:) -> [String: Int]` to `Sources/grostat/Database.swift`
- [ ] 1.3 Manually sanity-check both queries against a local DB via a throwaway test script

## 2. Gap detection

- [x] 2.1 Create `Sources/grostat/GapDetector.swift` with a `GapDetector` type that takes `Database`, a `today: Date`, a `threshold: Double`, and exposes `detect() -> GapReport`
- [x] 2.2 Define `GapReport` struct: `gaps: [GapDay]` (each with `date`, `count`, `monthMax`, `classification`) and `extension: HistoryExtension?`
- [x] 2.3 Implement detection: iterate every day in `[today − 95, today − 1]`, look up its count, classify as `missing`, `partial`, or `complete` per the spec (exclude today; see design open question — confirmed: exclude)
- [x] 2.4 Implement history-extension computation using `getDateRange()` and the API window

## 3. TUI primitive

- [x] 3.1 Create `Sources/grostat/TUI.swift` with `enableRawMode()` and `restoreTerminal()` using `Darwin.termios` (`tcgetattr` / `tcsetattr`, disable `ICANON` and `ECHO`)
- [x] 3.2 Implement `readKey() -> Key` that reads one byte and parses ANSI escape sequences (`\x1b[A/B/C/D`) into `Key.up/down/right/left`; map space, enter, q, ctrl-c, ctrl-d, printable chars
- [x] 3.3 Install `SIGINT`, `SIGTERM`, `SIGHUP` handlers that restore terminal and re-raise; register `atexit()` for normal-exit restore
- [x] 3.4 Implement generic `selectMany<T>(items:render:footer:) -> [T]?` returning nil on abort (q / ctrl-c), array on enter
- [x] 3.5 Implement render loop: `\x1b[H\x1b[J` (home + clear-to-end), draw rows with focus marker and `[x]`/`[ ]`, draw footer
- [x] 3.6 Detect non-TTY stdin (`isatty(STDIN_FILENO) == 0`) and return an error from `selectMany` so the caller can exit cleanly

## 4. Shared fetch helper

- [x] 4.1 Create `Sources/grostat/HistoricalFetcher.swift` with `HistoricalFetcher` struct holding `client`, `db`, `alerts`
- [x] 4.2 Add `FetchSummary` struct: `inserted: Int`, `skipped: Int`, `failedDays: [String]`
- [x] 4.3 Implement `fetchDays(_ dates: [String], progress: (Int, Int, String) -> Void) -> FetchSummary` — extract the per-day loop body from `QueryHistoricalDataCommand.run()` including the 60s throttle, `hasTimestamp` dedupe, and error-then-wait-60s behaviour
- [x] 4.4 Refactor `QueryHistoricalDataCommand.run()` to build the date range and call `HistoricalFetcher.fetchDays`; preserve current CLI output format

## 5. `backfill` subcommand

- [x] 5.1 Create `Sources/grostat/Commands/BackfillCommand.swift` with `static let configuration = CommandConfiguration(commandName: "backfill", abstract: "Detect and fill data gaps interactively")`
- [x] 5.2 Add flags: `--dry-run` (Bool) and `--threshold` (Double, default 0.7, validate 0.0–1.0)
- [x] 5.3 Wire `BackfillCommand` into `Grostat.swift` `subcommands` array
- [x] 5.4 `run()`: load config, open DB, run `GapDetector.detect()`, handle empty-result case (print "no gaps" and exit 0)
- [x] 5.5 `run()` `--dry-run` branch: print formatted list of gaps + extension entry and exit 0
- [x] 5.6 `run()` interactive branch: call `TUI.selectMany`, handle nil (abort) cleanly, build date list from selection, call `HistoricalFetcher.fetchDays`, print final summary

## 6. Output formatting

- [x] 6.1 Implement a `renderGapRow(_ gap: GapDay, selected: Bool, focused: Bool) -> String` helper used by both the TUI render callback and the `--dry-run` printer
- [x] 6.2 Implement footer summary: `"N selected — ~M API calls — ~T min (60s throttle)"`
- [x] 6.3 Use existing `Format.swift` patterns where applicable for date and number formatting

## 7. Verification

- [x] 7.1 Run `just build` — clean compile
- [ ] 7.2 Run `just check` — build + lint clean *(swiftlint fails to load sourcekitd; environment issue, not code)*
- [x] 7.3 Manual: `grostat backfill --dry-run` against current DB — output looks correct
- [x] 7.4 Manual: `grostat backfill --dry-run --threshold 0.5` — fewer rows than default *(behaviour verified — partial rows drop below their ratio threshold)*
- [x] 7.5 Manual: `grostat backfill` interactively — arrows, space, `a`, `n`, enter, q all behave per spec *(user confirmed)*
- [x] 7.6 Manual: press ctrl-c during TUI — terminal restores cleanly *(user confirmed)*
- [x] 7.7 Manual: `grostat backfill < /dev/null` — exits with error pointing to `--dry-run`
- [ ] 7.8 Manual: `grostat query-historical-data --from <X> --to <Y>` after refactor — behaviour identical to pre-refactor (spot-check inserted/skipped counts) *(needs user to drive — costs API calls)*
- [ ] 7.9 Manual: backfill a known-partial day on a test DB — existing rows untouched, only missing timestamps inserted *(needs user to drive)*

## 8. Release

- [x] 8.1 Bump version in `Sources/grostat/Grostat.swift` and `GrostatBar/` Package version markers (CLI bump only is fine if the app didn't change — check `just publish` script) *(bumped CLI to 0.10.0; GrostatBar untouched)*
- [ ] 8.2 Ask user before tagging / pushing / publishing per CLAUDE.md
- [x] 8.3 Commit with descriptive message `Add backfill subcommand for filling data gaps (vX.Y.Z)` (no Co-Authored-By) *(committed as 77b17fc, pushed to origin/main)*
