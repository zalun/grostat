## Why

grostat CLI collects inverter data to SQLite but provides no at-a-glance visibility. Users must run `grostat status` in terminal to see current state. A macOS menu bar icon showing live production power and grid voltage status would provide instant awareness without opening anything.

## What Changes

- **New macOS menu bar app** (`GrostatBar.app`) showing inverter status in the menu bar
- **Menu bar icon**: SF Symbol changing by inverter state — sleep (`moon.zzz`), producing (`sun.max.fill`), on fire (`bolt.fill`), fault (`exclamationmark.triangle.fill`), offline (`questionmark.circle`)
- **Menu bar text**: current DC power in kW, colored by grid voltage status — green (<250V), orange (≥250V), red (≥253V)
- **Click popover**: detailed status panel (DC input, AC grid, temperature, energy, diagnostics)
- **Reads from existing SQLite** database — no API calls, depends on `grostat collect` via launchd
- **Refreshes every 60 seconds** from database
- **New config field**: `rated_power_w` (default 10000) — "on fire" threshold is 70% of this value
- **Distribution**: pre-built `.app` bundle in GitHub release, installed via Homebrew Cask or manually

## Capabilities

### New Capabilities
- `menubar-status`: Menu bar icon and text display with state-based icons and voltage-colored power text
- `menubar-popover`: Click-to-expand status panel with full inverter reading details
- `config-rated-power`: New `rated_power_w` field in config for "on fire" power threshold calculation

### Modified Capabilities

## Impact

- **New Xcode project**: `GrostatBar.xcodeproj` in repo for building the `.app` bundle
- **Config change**: new `rated_power_w` field in `Config.swift` and `config.json`
- **Build pipeline**: `just publish` needs to also build and upload `GrostatBar.app` as release asset
- **Homebrew**: new Cask formula (or manual install) alongside existing CLI Formula
- **Dependencies**: SQLite3 (system), AppKit/SwiftUI — no external dependencies
