## Why

When the collector daemon is offline (machine off, crashed launchd agent, server unreachable, network down) readings are silently missed. The existing `query-historical-data` command can fetch a date range but requires the user to manually identify the gap window and blindly re-fetches days that are already complete. Users need a smarter, interactive flow that finds gaps in the database and lets them choose what to backfill — including extending history backwards toward the Growatt API limit (~95 days).

Tracks GitHub issue #5.

## What Changes

- Add `grostat backfill` CLI subcommand.
- Detect incomplete days by counting readings per day and comparing against the per-month maximum (default threshold: < 70% of the month's best day, plus a separate "missing entirely" category for zero-count days).
- Present detected gaps in an interactive TUI checkbox list (termios raw mode: ↑/↓ to move, space to toggle, `a` to select all, enter to confirm, `q` to quit).
- Include a "history extension" entry in the same TUI list when the oldest record in the DB is newer than `today − 95 days`.
- On confirmation, fetch the selected days from the Growatt API and insert only missing timestamps (preserve historical `alert` values — no recomputation, no delete).
- Add `--dry-run` flag: print the gap list and exit without prompting.
- Add `--threshold <0.0-1.0>` flag to override the 0.7 ratio.
- Refactor the per-day fetch loop out of `QueryHistoricalDataCommand` into a shared routine reused by `backfill`.

## Capabilities

### New Capabilities
- `data-backfill`: Detect gaps in the readings database, present them interactively, and fetch missing days from the Growatt API while preserving existing records.

### Modified Capabilities
<!-- None — no existing specs in openspec/specs/. -->

## Impact

- New file: `Sources/grostat/Commands/BackfillCommand.swift`.
- New file(s) for TUI primitives (termios raw mode wrapper, e.g., `Sources/grostat/TUI.swift`) — POSIX `termios.h` already available via Darwin module, no new SPM dependency.
- Refactor: `Sources/grostat/Commands/QueryHistoricalDataCommand.swift` — extract per-day fetch loop into a shared helper (likely in `API.swift` or a new `HistoricalFetcher.swift`) so `backfill` reuses the throttling and dedupe logic.
- Read-only additions to `Database.swift`: per-day count query, per-month max query, oldest-record query (the last one already exists as `getDateRange`).
- No schema changes. No new SPM dependencies. No changes to `GrostatBar` app or `GrostatShared`.
- Affects user-facing CLI surface (new subcommand) — no breaking changes to existing commands.
