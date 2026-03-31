## 1. Config: rated_power_w

- [x] 1.1 Add `ratedPowerW` field (default 10000) to `Config.swift` with JSON key `rated_power_w`
- [x] 1.2 Add `rated_power_w` to `DEFAULT_CONFIG` in `Config.swift`

## 2. Xcode project setup

- [x] 2.1 Create `GrostatBar/` directory with SPM project for a macOS menu bar app (LSUIElement=true, no dock icon)
- [x] 2.2 Configure target: macOS 13+, Swift, AppKit lifecycle (not SwiftUI App lifecycle)
- [x] 2.3 Link system sqlite3 library

## 3. SQLite reader

- [x] 3.1 Create `StatusReader.swift` — opens DB read-only, queries latest row from `readings` table, returns a struct with all needed fields
- [x] 3.2 Add 60-second Timer to re-read database

## 4. State logic

- [x] 4.1 Create `InverterState.swift` — enum with cases: sleep, producing, onFire, fault, offline
- [x] 4.2 Create `VoltageLevel.swift` — enum: normal (<250V), warning (≥250V), critical (≥253V). Returns NSColor
- [x] 4.3 Stale data detection: reading older than 10 minutes → reduced opacity

## 5. Menu bar display

- [x] 5.1 Create `AppDelegate.swift` with NSStatusItem setup — SF Symbol icon + NSAttributedString for colored power text
- [x] 5.2 Implement icon selection based on InverterState
- [x] 5.3 Implement colored power text (kW) based on VoltageLevel
- [x] 5.4 Implement stale data dimming (50% opacity when >10min old)
- [x] 5.5 Hide power text when sleeping or offline (icon only)

## 6. Popover

- [x] 6.1 Create SwiftUI `StatusPopover.swift` — sections for DC Input, AC Grid, Temperature, Energy, Diagnostics
- [x] 6.2 Show header with device SN, last update timestamp, status badge
- [x] 6.3 Show "No data" message when DB is empty
- [x] 6.4 Add Quit button

## 7. Config reading

- [x] 7.1 Read `~/.config/grostat/config.json` for db_path, rated_power_w, alert thresholds at app startup
- [x] 7.2 Use db_path to locate SQLite database

## 8. Build & distribution

- [x] 8.1 Add `build-app` and `tarball-app` recipes to justfile
- [x] 8.2 Ad-hoc code sign the .app bundle (in bundle.sh)
- [x] 8.3 Update `just publish` to also build, zip, and upload GrostatBar.app
- [x] 8.4 Document manual install (download zip from releases) — Homebrew Cask deferred
