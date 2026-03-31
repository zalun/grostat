## Context

grostat CLI collects inverter data via launchd every 5 minutes into `~/.local/share/grostat/grostat.db`. A menu bar app needs to read this database and display live status. The app lives in the same repo as the CLI.

## Goals / Non-Goals

**Goals:**
- Menu bar app showing inverter state icon + power text with voltage-colored text
- Click popover with full status details
- Reads existing SQLite, no API calls
- Ships as pre-built `.app` bundle via GitHub release
- New `rated_power_w` config field for "on fire" threshold (70%)

**Non-Goals:**
- Statistics/charts app (later)
- API calls from the menu bar app
- App Store distribution
- Login/auth — reads local DB only

## Decisions

### 1. Xcode project for menu bar app

**Choice**: `GrostatBar/GrostatBar.xcodeproj` in repo.

**Alternatives**: Pure SPM (no asset catalog, hacky AppKit), single Package.swift with shared library target.

**Rationale**: Menu bar apps need an `.app` bundle with `Info.plist` (`LSUIElement = true` to hide from dock). Xcode project is the standard way. CLI stays as `swift build`, app builds with `xcodebuild`.

### 2. AppKit NSStatusBar + SwiftUI popover

**Choice**: `NSStatusItem` for menu bar icon/text, SwiftUI `NSPopover` for the detail panel.

**Rationale**: NSStatusItem gives full control over icon + attributed text color. SwiftUI popover for the detail view is faster to build than pure AppKit.

### 3. Read SQLite directly (no shared library)

**Choice**: Menu bar app has its own SQLite reader — a simple read-only query of the `readings` table.

**Alternatives**: Extract `GrostatCore` shared library from CLI.

**Rationale**: The reader is ~30 lines (open DB, SELECT latest row, close). Shared library adds build complexity for minimal code reuse. Can refactor later if needed.

### 4. Config reading

**Choice**: App reads `~/.config/grostat/config.json` for `db_path`, `rated_power_w`, alert thresholds.

**Rationale**: Same config as CLI. No duplication. User configures once.

### 5. Distribution: pre-built .app in release tarball

**Choice**: `just publish` builds the `.app`, zips it, uploads to GitHub release. Homebrew Cask formula installs to `/Applications/`.

**Rationale**: No compilation on user's machine. Same pattern as CLI binary.

## Risks / Trade-offs

**[Stale data]** → App reads DB, but `grostat collect` may not be running. Mitigation: show "Last update: X min ago" and dim icon if data is older than 10 minutes.

**[Code signing]** → macOS may block unsigned `.app`. Mitigation: ad-hoc signing for now (`codesign --force --sign -`). If needed, proper Developer ID later.

**[Two build systems]** → CLI uses `swift build`, app uses `xcodebuild`. Mitigation: justfile handles both. User runs `just publish` and doesn't care.
