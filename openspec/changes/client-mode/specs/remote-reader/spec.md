## ADDED Requirements

### Requirement: RemoteReader conforms to ReadingProvider
`RemoteReader` SHALL conform to `ReadingProvider`, fetching data from the HTTP API server instead of local SQLite.

#### Scenario: Read latest from server
- **WHEN** `readLatest()` is called on `RemoteReader`
- **THEN** it SHALL send `GET /status` to the configured server and return the decoded `InverterReading`

#### Scenario: Read range from server
- **WHEN** `readRange(from: date1, to: date2)` is called on `RemoteReader`
- **THEN** it SHALL send `GET /readings?from=YYYY-MM-DD&to=YYYY-MM-DD` to the server and return the decoded array

#### Scenario: Server unreachable
- **WHEN** the server is unreachable or returns an error
- **THEN** `readLatest()` SHALL return `nil` and `readRange()` SHALL return an empty array

### Requirement: RemoteReader fetches config from server
`RemoteReader` SHALL fetch display configuration from the server's `/config` endpoint.

#### Scenario: Config fetched on connection
- **WHEN** `RemoteReader` first connects to a server
- **THEN** it SHALL fetch `GET /config` and make `device_sn`, `rated_power_w`, `alert_warning_v`, and `alert_critical_v` available to the app

### Requirement: Polling interval
`RemoteReader` SHALL be used with the same 60-second refresh interval as the local `StatusReader`.

#### Scenario: Consistent polling
- **WHEN** GrostatBar is in client mode
- **THEN** the `AppDelegate` refresh timer SHALL call `RemoteReader.readLatest()` every 60 seconds, identical to local mode
