# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Grostat — Growatt inverter data collector and macOS menu bar app. Two SPM targets:
- `grostat` CLI (`Sources/grostat/`) — fetches telemetry from Growatt API, stores in SQLite
- `GrostatBar` menu bar app (`GrostatBar/`) — separate Package.swift, SwiftUI, reads data locally or via LAN server
- `GrostatShared` library (`Sources/GrostatShared/`) — shared models between CLI and app

Swift 5.9, macOS 13+. Single dependency: swift-argument-parser.

## Build & Run

```
just build          # debug build (CLI)
just release        # release build (CLI)
just build-app      # build GrostatBar.app
just install        # build CLI + app, install to ~/.local/bin/ and /Applications/
just check          # build + lint
just fmt            # swift-format (optional, skipped if not installed)
just lint           # swiftlint (optional, skipped if not installed)
```

No unit tests in project.

## Release

Use `just publish VERSION`. Always bump version — never retag or reuse version numbers. Always ask user for confirmation before tagging, pushing, or publishing releases.

## Commits

Descriptive message with version tag in parentheses: `Add feature X, fix Y (v0.8.12)`. Do NOT add Co-Authored-By lines.

## Design

UI design system documented in @.impeccable.md — read before making visual changes to GrostatBar.

## Environment

Config via `~/.config/grostat/config.json` or env vars: `GROSTAT_TOKEN`, `GROSTAT_DEVICE_SN`, `GROSTAT_DB_PATH`, `GROSTAT_ALERT_WARNING_V`, `GROSTAT_ALERT_CRITICAL_V`.
