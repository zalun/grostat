## Context

GrostatBar is a macOS menu bar app that reads inverter data from a local SQLite database populated by `grostat collect`. The CLI and menu bar app are separate SPM packages (`Package.swift` at root and `GrostatBar/Package.swift`). They share no code — `InverterReading` is duplicated with the menu bar version being a subset.

The app uses AppKit for the status item + SwiftUI for views. Data flows through `StatusReader` (SQLite, read-only) → `AppDelegate` (60s timer) → UI. `StatsDataManager` handles chart aggregation via `StatusReader.readRange()`.

Target platform: macOS 13+ (already the minimum). Network.framework (`NWListener`, `NWBrowser`) is available.

## Goals / Non-Goals

**Goals:**
- A second Mac on the LAN can display inverter data without running its own collector or having a local database
- Zero-config discovery via Bonjour when possible
- Local-only mode (no `server_enabled`) remains identical to today — zero networking overhead
- Single source of truth for `InverterReading` across CLI and menu bar app
- No external dependencies added

**Non-Goals:**
- Internet/WAN access (use Tailscale/VPN — out of scope)
- TLS or authentication (LAN-only, trusted network)
- Server-Sent Events / push updates (separate issue)
- Multiple simultaneous data sources / multi-inverter aggregation
- CLI acting as server (server lives in GrostatBar only)

## Decisions

### 1. Shared SPM library via local package dependency

Extract `InverterReading` and `ReadingProvider` into `Sources/GrostatShared/`. The root `Package.swift` gains a library target. `GrostatBar/Package.swift` adds `.package(path: "..")` to depend on it.

**Why over monorepo single Package.swift**: Keeps the existing build boundary. `cd GrostatBar && swift build` continues to work. `bundle.sh` and `just bar` are unchanged. GrostatBar's AppKit/SwiftUI dependencies stay isolated from the CLI.

**Why over no sharing**: With the HTTP API as a third serialization point, maintaining `InverterReading` in three places would guarantee drift. The menu bar's version is already a subset that's missing fields.

### 2. `ReadingProvider` protocol as the abstraction boundary

```swift
protocol ReadingProvider {
    func readLatest() -> InverterReading?
    func readRange(from: Date, to: Date) -> [InverterReading]
}
```

`StatusReader` (SQLite) and `RemoteReader` (HTTP) both conform. `AppDelegate` picks the provider based on `BarConfig.mode`. Everything downstream (`StatsDataManager`, popover, charts) is unchanged.

**Why a protocol and not an enum**: The two providers have very different internals (SQLite bindings vs URLSession). A protocol keeps them decoupled. Also allows testing with a mock provider later.

### 3. NWListener for HTTP server (no external dependencies)

Foundation's `Network` framework provides `NWListener` for TCP connections. The server parses raw HTTP requests (only 4 simple GET endpoints) and returns JSON. No need for a full HTTP framework.

**Alternatives considered**:
- **Vapor/Hummingbird**: Adds a large dependency tree for 4 endpoints. Overkill.
- **python -m http.server style subprocess**: Violates "server runs inside GrostatBar.app" requirement.
- **GCDAsyncSocket**: Deprecated in favor of Network.framework.

### 4. Bonjour discovery in v1 with user picker

Server advertises `_grostat._tcp` with TXT record containing `device_sn` and `version`. Client uses `NWBrowser` to discover services.

- 0 servers found → "Searching..." in menu bar, keeps browsing
- 1 server found → auto-connect
- N servers found → SwiftUI picker showing device SN + hostname

User's choice is persisted as `"server"` in config for instant reconnect on next launch. Bonjour remains active as fallback if the saved server disappears.

**Why not manual-only**: The whole point of client mode is low friction. Typing `mac-studio.local:7654` is a bad first experience when Bonjour is free on macOS.

### 5. Server opt-in via config flag

```json
{ "mode": "local", "server_enabled": true, "server_port": 7654 }
```

Default: `server_enabled = false`. Local mode without the flag is byte-for-byte identical behavior to today. The networking code exists in the binary but is never instantiated.

**Why opt-in**: Opening a network port is a side effect users should explicitly choose. A Mac running GrostatBar for personal use shouldn't unexpectedly become a server.

### 6. Full DB row over API

The `/readings` and `/status` endpoints return all columns from the SQLite `readings` table, not just the subset the menu bar currently uses. `InverterReading` is `Codable` — serialization is automatic.

**Why**: Decouples the API contract from the current UI. If the UI later uses more fields (already available in the CLI's version), no API change needed.

### 7. Client config inherits from server

The `/config` endpoint serves `device_sn`, `rated_power_w`, `alert_warning_v`, `alert_critical_v`. The client's `BarConfig` only needs `mode` (and optionally `server`). All display-relevant config comes from the host.

**Why**: Avoids config duplication and drift. The host is the authority — it knows the inverter.

## Risks / Trade-offs

**[Risk] NWListener HTTP parsing is manual** → Keep the parser minimal (only GET, no chunked encoding, no keep-alive in v1). 4 endpoints with JSON responses. Test with curl.

**[Risk] Bonjour may not work across VLANs** → Document that server and client must be on the same subnet. Manual `"server"` config is the escape hatch.

**[Risk] SQLite WAL + concurrent HTTP reads** → SQLite WAL mode already supports concurrent readers. The server reads through the same `StatusReader` that the menu bar UI uses. No new concurrency concern.

**[Risk] Menu bar app crash takes down the server** → Acceptable. This is a monitoring tool, not critical infrastructure. If the app restarts, the server restarts.

**[Trade-off] No auth on LAN** → Anyone on the LAN can read inverter data. Acceptable for a home network. Document that users wanting security should use Tailscale.

**[Trade-off] Polling, not push** → Client polls every 60s, same as local mode. Adds ~1KB/minute of LAN traffic. Push (SSE) deferred to separate issue.
