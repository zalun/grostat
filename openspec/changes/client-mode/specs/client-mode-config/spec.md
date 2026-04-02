## ADDED Requirements

### Requirement: Mode field in BarConfig
`BarConfig` SHALL support a `mode` field with values `"local"` (default) and `"client"`.

#### Scenario: Default mode is local
- **WHEN** `mode` is absent from the config file
- **THEN** `BarConfig.mode` SHALL default to `"local"` and behavior SHALL be identical to the current app

#### Scenario: Client mode set
- **WHEN** config contains `"mode": "client"`
- **THEN** the app SHALL use `RemoteReader` instead of `StatusReader` and SHALL NOT open the SQLite database

### Requirement: Server-enabled field
`BarConfig` SHALL support a `server_enabled` boolean field, defaulting to `false`.

#### Scenario: Server enabled in local mode
- **WHEN** config contains `"mode": "local"` and `"server_enabled": true`
- **THEN** the HTTP server and Bonjour advertisement SHALL start

#### Scenario: Server disabled by default
- **WHEN** `server_enabled` is absent from the config file
- **THEN** no HTTP server SHALL start and no port SHALL be opened

### Requirement: Server port field
`BarConfig` SHALL support a `server_port` integer field, defaulting to `7654`.

#### Scenario: Custom port
- **WHEN** config contains `"server_port": 8080`
- **THEN** the HTTP server SHALL listen on port 8080 instead of 7654

### Requirement: Server address field for client mode
`BarConfig` SHALL support a `server` string field for manually specifying the host server address.

#### Scenario: Manual server address
- **WHEN** config contains `"mode": "client"` and `"server": "mac-studio.local:7654"`
- **THEN** the app SHALL connect directly to that address without Bonjour discovery

#### Scenario: No server address triggers discovery
- **WHEN** config contains `"mode": "client"` and no `"server"` field
- **THEN** the app SHALL use Bonjour browsing to find a server

### Requirement: Local mode without server is unchanged
When `mode` is `"local"` and `server_enabled` is `false` or absent, the app SHALL behave identically to the current version with zero networking code instantiated.

#### Scenario: Backward compatibility
- **WHEN** an existing config file with no `mode`, `server_enabled`, or `server` fields is loaded
- **THEN** the app SHALL operate in local-only mode, reading from SQLite, with no network activity
