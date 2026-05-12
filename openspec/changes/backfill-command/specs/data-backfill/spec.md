## ADDED Requirements

### Requirement: Gap detection by per-day reading count

The system SHALL detect incomplete days in the readings database by counting readings per calendar day (local time, derived from the `timestamp` column) and comparing each day's count against the maximum daily count observed in the same calendar month within the database.

A day SHALL be classified as one of:

- **missing** — the day has zero readings in the database.
- **partial** — the day has at least one reading but its count is strictly less than `threshold × monthMax`, where `monthMax` is the highest daily count for the same `YYYY-MM` and `threshold` defaults to `0.7`.
- **complete** — otherwise. Complete days SHALL NOT be listed.

Detection SHALL be limited to the date range `[max(today − 95 days, oldestRecordDate), today − 1 day]`. Days earlier than the oldest record in the database SHALL NOT be classified as gaps; they belong to the separate "history extension" entry. If the database is empty, no gaps SHALL be reported.

If a calendar month contains only a single day of data, `monthMax` for that month equals that day's count, so no day in that month can be classified as `partial` (only `missing`).

#### Scenario: Day with zero readings is missing

- **WHEN** the database contains no rows where `date(timestamp) = '2026-04-28'` and 2026-04-28 is within the last 95 days
- **THEN** 2026-04-28 SHALL be reported as `missing`

#### Scenario: Day below threshold relative to month max is partial

- **WHEN** April's best day has 168 readings and 2026-04-12 has 47 readings (28% of monthMax)
- **THEN** 2026-04-12 SHALL be reported as `partial` with count 47 of 168

#### Scenario: Day at or above threshold is not listed

- **WHEN** April's best day has 168 readings and 2026-04-15 has 152 readings (90% of monthMax)
- **THEN** 2026-04-15 SHALL NOT appear in the gap list

#### Scenario: Custom threshold flag overrides default

- **WHEN** the user runs `grostat backfill --threshold 0.5` and a day has 60% of monthMax
- **THEN** that day SHALL NOT be reported (60% ≥ 50%)

#### Scenario: Detection ignores days older than the API window

- **WHEN** today is 2026-05-12 and a day with zero readings is 2026-01-15 (more than 95 days ago)
- **THEN** 2026-01-15 SHALL NOT appear in the gap list

### Requirement: History extension offer

The system SHALL compute the oldest timestamp in the database (`MIN(timestamp)`) and, if that timestamp is strictly later than `today − 95 days`, SHALL offer a single "history extension" entry covering the range `[today − 95 days, oldestRecord − 1 day]`.

If the database is empty, the offered range SHALL be the full API window `[today − 95 days, today − 1 day]`.

If the oldest record is already at or beyond the API limit, no extension entry SHALL be offered.

#### Scenario: Oldest record newer than API limit

- **WHEN** today is 2026-05-12, oldest record is 2026-02-15, and API limit is 2026-02-06
- **THEN** the system SHALL offer to extend history with 9 days (2026-02-06 through 2026-02-14)

#### Scenario: Empty database

- **WHEN** the database has no readings
- **THEN** the system SHALL offer to extend history covering the full 95-day API window

#### Scenario: Oldest record at API limit

- **WHEN** the oldest record is older than `today − 95 days`
- **THEN** no history extension entry SHALL be offered

### Requirement: Interactive selection TUI

The system SHALL present the detected gaps and any history extension entry in an interactive terminal UI when invoked without `--dry-run`.

The TUI SHALL:

- Place the terminal into raw mode using `termios` (disable `ICANON` and `ECHO`) and restore the original `termios` state on exit, including on `SIGINT`, `SIGTERM`, and normal termination.
- Render the list with one selectable entry per gap day, plus one optional entry at the end for history extension.
- Indicate the focused row visually (e.g., `▶` marker) and selected rows as `[x]` / unselected as `[ ]`.
- Support these key bindings:
  - `↑` / `↓` arrows — move focus
  - `space` — toggle selection of focused row
  - `a` — select all
  - `n` — deselect all
  - `enter` — confirm and proceed to fetch
  - `q` or `ctrl-c` — abort without fetching
- Display a footer summarizing the selection: number of selected items, approximate number of API calls (one per day), and estimated time given the 60-second per-call throttle.

If standard input is not a TTY, the system SHALL exit with an error instructing the user to run with `--dry-run` or in an interactive terminal.

#### Scenario: User toggles a row with space

- **WHEN** the focused row is unselected and the user presses space
- **THEN** the row SHALL become selected and the footer count SHALL increase by one

#### Scenario: User selects all with 'a'

- **WHEN** the user presses `a`
- **THEN** every row SHALL become selected

#### Scenario: User aborts with q

- **WHEN** the user presses `q`
- **THEN** the system SHALL restore the terminal state and exit without making any API calls

#### Scenario: User aborts with ctrl-c

- **WHEN** the user presses ctrl-c during the TUI
- **THEN** the system SHALL restore the terminal state via its `SIGINT` handler and exit

#### Scenario: Non-interactive stdin

- **WHEN** stdin is not a TTY (e.g., piped input) and `--dry-run` was not passed
- **THEN** the system SHALL exit with a non-zero status and an error message pointing to `--dry-run`

### Requirement: Dry-run listing

The system SHALL support a `--dry-run` flag that prints the detected gaps and any history extension entry as a plain text list, then exits with status zero without making any API calls and without entering the TUI.

The output SHALL include, for each gap: the date, classification (`missing` or `partial`), reading count, the relevant `monthMax`, and the ratio as a percentage.

#### Scenario: Dry run prints and exits

- **WHEN** the user runs `grostat backfill --dry-run` and the database contains two gap days
- **THEN** the system SHALL print both gap days with their classification and exit with status 0 without invoking the API

#### Scenario: Dry run with no gaps

- **WHEN** the database contains no incomplete days within the API window and the oldest record is at the API limit
- **THEN** the system SHALL print a message indicating no gaps were found and exit with status 0

### Requirement: Fetch preserves existing records

For each day the user confirms (gap or history extension), the system SHALL invoke the Growatt historical API and, for every returned reading, SHALL insert it only if no row with that exact `timestamp` already exists. Existing rows SHALL NOT be updated, deleted, or have their `alert` column recomputed.

The fetch loop SHALL apply the same 60-second per-call throttle used by `query-historical-data` between successive API calls.

On API error for a given day, the system SHALL log the error, wait 60 seconds, and continue with the next day. The system SHALL NOT abort the whole batch on a single-day failure.

At completion, the system SHALL print a summary: total inserted, total duplicates skipped, total days with errors.

#### Scenario: Existing timestamps are skipped

- **WHEN** the user backfills a partial day where 47 of 168 timestamps are already in the database
- **THEN** the system SHALL insert the 121 new readings and SHALL NOT modify the 47 existing rows

#### Scenario: Alert values are not recomputed

- **WHEN** a day is backfilled and the user's alert thresholds in config differ from when the existing rows were written
- **THEN** existing rows in that day SHALL retain their original `alert` column values; only newly inserted rows SHALL have alerts computed from the current config

#### Scenario: API error on one day does not abort

- **WHEN** the user selects three days and the API returns an error for the second day
- **THEN** the system SHALL log the error, wait 60 seconds, fetch the third day, and report the second day's failure in the final summary
