## ADDED Requirements

### Requirement: Environment-based configuration
The system SHALL read configuration from environment variables with prefix `GROSTAT_`, with fallback to a `.env` file in the current directory or user home.

Required settings:
- `GROSTAT_TOKEN` — Growatt API token (MUST be set, no default)
- `GROSTAT_DEVICE_SN` — device serial number (default: "NFB8922074")
- `GROSTAT_DB_PATH` — SQLite database path (default: "~/.local/share/grostat/grostat.db")
- `GROSTAT_ALERT_WARNING_V` — WARNING threshold (default: 250.0)
- `GROSTAT_ALERT_CRITICAL_V` — CRITICAL threshold (default: 253.0)
- `GROSTAT_API_BASE` — API base URL (default: "https://openapi.growatt.com/v4/new-api")

#### Scenario: Token from .env file
- **WHEN** `GROSTAT_TOKEN` is set in `.env` file and not in environment
- **THEN** the system SHALL use the value from `.env`

#### Scenario: Environment overrides .env
- **WHEN** `GROSTAT_TOKEN` is set both in environment and `.env`
- **THEN** the system SHALL use the environment variable value

#### Scenario: Missing required token
- **WHEN** `GROSTAT_TOKEN` is not set anywhere
- **THEN** the system SHALL exit with error message: "GROSTAT_TOKEN not set. Create a .env file or set the environment variable."

### Requirement: .env.example template
The project SHALL include a `.env.example` file documenting all configuration variables with placeholder values and comments.

#### Scenario: New user setup
- **WHEN** a user installs grostat for the first time
- **THEN** they can copy `.env.example` to `.env` and fill in their token to get started
