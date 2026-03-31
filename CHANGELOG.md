# Changelog

## 0.5.1

- Add file logging next to database (`~/.local/share/grostat/grostat.log`)
- Log rotation: 5 MB max, 3 rotations kept
- Schedule command logs to data directory instead of /tmp
- Fix justfile homebrew_repo path

## 0.5.0

- Add `grostat token` and `grostat device` commands to set config values
- Interactive `grostat init` — prompts for token and device SN
- Remove hardcoded device SN from default config
- Validate both token and device SN before collecting

## 0.4.0

- Complete rewrite in Swift — native binary, zero runtime dependencies
- 1.8 MB binary, installs in 0 seconds via Homebrew
- Same features as Python version: collect, status, summary, export, db-info
- Add `grostat schedule` / `grostat unschedule` for launchd automation
- Add justfile with build, release, and publish recipes
- Config via `~/.config/grostat/config.json` + environment variables
- SQLite via system sqlite3, macOS notifications via osascript
- Two-tier voltage alerts: WARNING ≥250V, CRITICAL ≥253V

## 0.3.x

- Python version (replaced by Swift in 0.4.0)
- pydantic-settings, Typer CLI, Rich tables
- Homebrew formula with Python dependency resources

## 0.1.0

- Initial Python release
- Basic data collection (AC voltages, power, energy)
- CSV storage, monthly rotation
