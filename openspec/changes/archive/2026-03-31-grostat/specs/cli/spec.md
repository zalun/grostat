## ADDED Requirements

### Requirement: collect command
The CLI SHALL provide a `grostat collect` command that fetches one reading from the API and stores it in SQLite. It SHALL also support `--loop` flag for continuous collection at a configurable interval (default 5 min).

#### Scenario: Single collection
- **WHEN** user runs `grostat collect`
- **THEN** the system SHALL fetch one reading, store it, print a one-line summary to stdout, and exit

#### Scenario: Loop mode
- **WHEN** user runs `grostat collect --loop`
- **THEN** the system SHALL collect readings every 5 minutes until interrupted with Ctrl+C

### Requirement: summary command
The CLI SHALL provide `grostat summary [DATE]` that displays a daily summary including: max/min/avg phase voltages, max power, total energy (max powerToday), alert count, fault count, temperature range.

#### Scenario: Today's summary
- **WHEN** user runs `grostat summary`
- **THEN** the system SHALL query the database for today's readings and display a formatted summary table

#### Scenario: Specific date summary
- **WHEN** user runs `grostat summary 2026-03-21`
- **THEN** the system SHALL display the summary for March 21, 2026

#### Scenario: No data for date
- **WHEN** user runs `grostat summary` and there are no readings for the requested date
- **THEN** the system SHALL print "No data for <date>" and exit

### Requirement: status command
The CLI SHALL provide `grostat status` that displays the most recent reading in a formatted table (Rich).

#### Scenario: Show last reading
- **WHEN** user runs `grostat status`
- **THEN** the system SHALL display the latest reading with all fields grouped by category (DC, AC, temp, energy, diagnostics)

#### Scenario: Empty database
- **WHEN** user runs `grostat status` with no readings in the database
- **THEN** the system SHALL print "No readings yet. Run 'grostat collect' first." and exit

### Requirement: export command
The CLI SHALL provide `grostat export [--from DATE] [--to DATE] [--output FILE]` that exports readings to CSV.

#### Scenario: Export all data
- **WHEN** user runs `grostat export`
- **THEN** the system SHALL export all readings to stdout in CSV format

#### Scenario: Export date range to file
- **WHEN** user runs `grostat export --from 2026-03-01 --to 2026-03-31 --output march.csv`
- **THEN** the system SHALL export readings from that date range to the specified file

### Requirement: db-info command
The CLI SHALL provide `grostat db-info` showing database file path, file size, row count, and date range of stored readings.

#### Scenario: Show database info
- **WHEN** user runs `grostat db-info`
- **THEN** the system SHALL display the database path, size in MB, total row count, and earliest/latest timestamp
