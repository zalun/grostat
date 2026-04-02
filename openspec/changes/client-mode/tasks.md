## 1. Shared Models Package

- [x] 1.1 Create `Sources/GrostatShared/` directory and add `GrostatShared` library target to root `Package.swift`
- [x] 1.2 Move `InverterReading` to `Sources/GrostatShared/InverterReading.swift` — merge all fields from both CLI and GrostatBar versions into one `Codable` struct
- [x] 1.3 Add `ReadingProvider` protocol to `Sources/GrostatShared/ReadingProvider.swift` with `readLatest()` and `readRange(from:to:)` methods
- [x] 1.4 Update `GrostatBar/Package.swift` to depend on root package via `.package(path: "..")` and import `GrostatShared`
- [x] 1.5 Update `grostat` CLI target to depend on `GrostatShared`; remove duplicate `InverterReading` from `Sources/grostat/Models.swift`
- [x] 1.6 Update `GrostatBar/Sources/StatusReader.swift` — remove inline `InverterReading`, import from `GrostatShared`, conform `StatusReader` to `ReadingProvider`
- [x] 1.7 Verify `just build` and `just bar` both succeed with shared dependency

## 2. Config Expansion

- [x] 2.1 Add `mode` (local/client), `serverEnabled`, `serverPort`, and `server` fields to `BarConfig` with backward-compatible defaults
- [x] 2.2 Update `AppDelegate` to select `ReadingProvider` based on `BarConfig.mode` — local mode uses `StatusReader` (unchanged path), client mode will use `RemoteReader` (stubbed for now)

## 3. HTTP API Server

- [x] 3.1 Create `GrostatBar/Sources/GrostatServer.swift` — `NWListener`-based HTTP server that accepts TCP connections and parses GET requests
- [x] 3.2 Implement `GET /status` — returns latest `InverterReading` as JSON (via `StatusReader.readLatest()`)
- [x] 3.3 Implement `GET /readings?date=` and `GET /readings?from=&to=` — returns `[InverterReading]` as JSON
- [x] 3.4 Implement `GET /config` — returns `device_sn`, `rated_power_w`, `alert_warning_v`, `alert_critical_v` as JSON
- [x] 3.5 Return HTTP 404 for unknown routes, HTTP 400 for missing parameters
- [x] 3.6 Wire server startup in `AppDelegate` — start only when `mode == .local && serverEnabled == true`

## 4. Bonjour Discovery

- [x] 4.1 Add Bonjour advertisement to `GrostatServer` — advertise `_grostat._tcp` with TXT record (`device_sn`, `version`) when server starts; remove on stop
- [x] 4.2 Create `GrostatBar/Sources/ServerBrowser.swift` — `NWBrowser` wrapper that discovers `_grostat._tcp` services and reports results via callback
- [x] 4.3 Create `GrostatBar/Sources/ServerPickerView.swift` — SwiftUI view showing discovered servers (device SN + hostname) with selection action

## 5. Remote Reader (Client Mode)

- [x] 5.1 Create `GrostatBar/Sources/RemoteReader.swift` conforming to `ReadingProvider` — implements `readLatest()` via `GET /status` and `readRange()` via `GET /readings`
- [x] 5.2 Add config fetch — on first connection, `GET /config` and expose `device_sn`, `rated_power_w`, alert thresholds to the app
- [x] 5.3 Handle server unreachable — `readLatest()` returns `nil`, `readRange()` returns `[]`

## 6. Client Mode Wiring

- [x] 6.1 Wire `AppDelegate` client mode — if `server` in config, create `RemoteReader` directly; otherwise start `ServerBrowser`
- [x] 6.2 Implement discovery flow — auto-connect on 1 result, show picker on multiple, show "Searching..." on none
- [x] 6.3 Persist user's server choice to config file after picker selection
- [x] 6.4 Implement fallback — if saved server unreachable after 3 attempts, restart Bonjour browsing

## 7. Verification

- [ ] 7.1 Test local mode without `server_enabled` — verify zero network activity, identical behavior to current version (manual)
- [ ] 7.2 Test local mode with `server_enabled: true` — verify server responds on port, Bonjour visible via `dns-sd -B _grostat._tcp` (manual)
- [ ] 7.3 Test client mode with manual `server` config — verify readings display, stats charts work (manual)
- [ ] 7.4 Test client mode with Bonjour discovery — verify auto-connect and picker flow (manual)
- [ ] 7.5 Test backward compatibility — existing config files without new fields work unchanged (manual)
