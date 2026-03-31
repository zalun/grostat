## 1. Project Scaffolding

- [x] 1.1 Create `pyproject.toml` with project metadata, dependencies (requests, typer, pydantic-settings, rich), dev dependencies (ruff, ty), console script entry point `grostat = "grostat.cli:app"`, and ruff/ty config
- [x] 1.2 Create `src/grostat/__init__.py` with version
- [x] 1.3 Create `.env.example` with all GROSTAT_* variables documented
- [x] 1.4 Create `.gitignore` (*.db, .env, __pycache__, .venv, dist/)

## 2. Configuration

- [x] 2.1 Create `src/grostat/config.py` — pydantic-settings `Settings` class with GROSTAT_ prefix, .env file support, all fields with defaults per spec (token required, device_sn, db_path, alert_warning_v=250.0, alert_critical_v=253.0, api_base)
- [x] 2.2 Ensure db_path parent directory is auto-created on first use

## 3. Data Models

- [x] 3.1 Create `src/grostat/models.py` — `InverterReading` dataclass with all ~35 fields, class method `from_api_response(data: dict)` that maps API field names to snake_case attributes, computes phase voltages, and sets vmax_phase

## 4. API Client

- [x] 4.1 Create `src/grostat/api.py` — `GrowattClient` class with `fetch_last_data() -> InverterReading`, retry logic (2 retries, 10s delay), proper error handling and logging

## 5. SQLite Storage

- [x] 5.1 Create `src/grostat/db.py` — `Database` class: init (create table + indexes if not exist), `insert_reading(reading: InverterReading)`, `get_latest() -> dict | None`, `get_readings_for_date(date) -> list[dict]`, `get_date_range() -> tuple`, `get_row_count() -> int`, `export_readings(from_date, to_date) -> list[dict]`
- [x] 5.2 Enable WAL mode on database open

## 6. Alert System

- [x] 6.1 Create `src/grostat/alerts.py` — `AlertChecker` class: evaluate reading against two thresholds (WARNING ≥250V, CRITICAL ≥253V), return alert level string
- [x] 6.2 Implement macOS notification via `osascript` subprocess call, with platform check (skip silently on non-macOS)

## 7. CLI

- [x] 7.1 Create `src/grostat/cli.py` — Typer app with `collect` command (single shot + --loop flag)
- [x] 7.2 Add `summary` command — query DB for date, display Rich table with max/min/avg voltages, max power, energy, alert/fault counts, temp range
- [x] 7.3 Add `status` command — display latest reading as Rich table grouped by category
- [x] 7.4 Add `export` command — CSV export with --from, --to, --output options
- [x] 7.5 Add `db-info` command — show db path, size, row count, date range

## 8. Integration & Polish

- [x] 8.1 Wire everything together: collect command creates Settings, GrowattClient, Database, AlertChecker, fetches reading, stores, checks alerts
- [x] 8.2 Set up logging (file + stderr) consistent with cron usage
- [x] 8.3 Verify `uv run grostat collect` works end-to-end
- [x] 8.4 Run `ruff check` and `ruff format` — fix all issues
- [x] 8.5 Run `ty check` — add type annotations, fix all issues

## 9. Homebrew Distribution

- [x] 9.1 Create Homebrew formula template (`Formula/grostat.rb`) for the tap repo
- [x] 9.2 Document release process (tag → GitHub release → update formula SHA) in README or CONTRIBUTING
