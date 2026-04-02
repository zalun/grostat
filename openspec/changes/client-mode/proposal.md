## Why

GrostatBar currently requires a local SQLite database filled by `grostat collect`. On a second Mac (e.g., a MacBook), this means running a separate collector with its own API token and database. Issue #3 proposes a **client mode** where one Mac (the host) serves inverter data over the LAN and other Macs display it without needing their own database or collector.

## What Changes

- **Shared `InverterReading` type** — extract the duplicated struct into a `GrostatShared` SPM library target, used by both `grostat` CLI and `GrostatBar`. Adds `ReadingProvider` protocol so the UI layer is agnostic to data source.
- **HTTP API server** — opt-in embedded HTTP server in GrostatBar (local mode) serving readings from SQLite. Endpoints: `/status`, `/readings`, `/config`. Uses Foundation `NWListener`, zero external dependencies.
- **Bonjour/mDNS discovery** — server advertises `_grostat._tcp` on LAN. Client auto-discovers available servers, shows a picker when multiple are found, and persists the user's choice.
- **HTTP client data provider** — `RemoteReader` conforming to `ReadingProvider`, fetching data from the server API. Polls on the same 60s interval as the local reader.
- **Config expansion** — new fields: `mode` (local/client), `server_enabled`, `server_port`, `server`. Local mode without `server_enabled` behaves exactly as today (zero networking).

## Capabilities

### New Capabilities
- `shared-models`: Shared `InverterReading` type and `ReadingProvider` protocol extracted into `GrostatShared` SPM library
- `http-api-server`: Embedded HTTP server in GrostatBar serving inverter data from SQLite over LAN
- `bonjour-discovery`: mDNS service advertisement and browsing for zero-config server discovery
- `remote-reader`: HTTP client implementing `ReadingProvider` for client-mode data fetching
- `client-mode-config`: Extended `BarConfig` supporting local/client mode switching and server settings

### Modified Capabilities

_(none — no existing specs)_

## Impact

- **GrostatBar/Sources/StatusReader.swift** — `InverterReading` struct moves to shared package; `StatusReader` gains `ReadingProvider` conformance
- **Sources/grostat/Models.swift** — `InverterReading` struct replaced by import from shared package
- **Package.swift** — new `GrostatShared` library target
- **GrostatBar/Package.swift** — new dependency on parent package for `GrostatShared`
- **GrostatBar/Sources/BarConfig.swift** — new config fields for mode, server settings
- **GrostatBar/Sources/AppDelegate.swift** — provider selection based on config mode
- **New files**: `RemoteReader.swift`, `GrostatServer.swift`, `ServerBrowser.swift`, `ServerPickerView.swift`
- **Dependencies**: None added. Uses Foundation `Network` framework (NWListener, NWBrowser) already available on macOS 13+
