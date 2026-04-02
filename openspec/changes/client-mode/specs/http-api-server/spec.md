## ADDED Requirements

### Requirement: Embedded HTTP server
GrostatBar SHALL include an embedded HTTP server using Foundation `NWListener` that serves inverter data from the local SQLite database. The server SHALL only start when `server_enabled` is `true` in config.

#### Scenario: Server starts when enabled
- **WHEN** GrostatBar launches with `mode: "local"` and `server_enabled: true`
- **THEN** an HTTP server SHALL start listening on the configured `server_port` (default 7654)

#### Scenario: Server does not start when disabled
- **WHEN** GrostatBar launches with `mode: "local"` and `server_enabled` is `false` or absent
- **THEN** no network listener SHALL be created and no port SHALL be opened

#### Scenario: Server does not start in client mode
- **WHEN** GrostatBar launches with `mode: "client"`
- **THEN** no HTTP server SHALL be started

### Requirement: GET /status endpoint
The server SHALL respond to `GET /status` with the latest inverter reading as JSON.

#### Scenario: Latest reading available
- **WHEN** a client sends `GET /status`
- **THEN** the server SHALL respond with HTTP 200 and a JSON-encoded `InverterReading` representing the most recent row from SQLite

#### Scenario: No readings in database
- **WHEN** a client sends `GET /status` and the database has no rows
- **THEN** the server SHALL respond with HTTP 204 No Content

### Requirement: GET /readings endpoint with date query
The server SHALL respond to `GET /readings` with readings filtered by date parameters.

#### Scenario: Single day query
- **WHEN** a client sends `GET /readings?date=2024-06-15`
- **THEN** the server SHALL respond with HTTP 200 and a JSON array of all `InverterReading` entries for that date

#### Scenario: Date range query
- **WHEN** a client sends `GET /readings?from=2024-06-01&to=2024-06-15`
- **THEN** the server SHALL respond with HTTP 200 and a JSON array of all `InverterReading` entries within that range (inclusive)

#### Scenario: Missing date parameters
- **WHEN** a client sends `GET /readings` without `date` or `from`/`to` parameters
- **THEN** the server SHALL respond with HTTP 400 Bad Request

### Requirement: GET /config endpoint
The server SHALL respond to `GET /config` with display-relevant configuration.

#### Scenario: Config response
- **WHEN** a client sends `GET /config`
- **THEN** the server SHALL respond with HTTP 200 and a JSON object containing `device_sn`, `rated_power_w`, `alert_warning_v`, and `alert_critical_v`

### Requirement: Unknown routes return 404
The server SHALL respond with HTTP 404 for any request path not matching a defined endpoint.

#### Scenario: Unknown path
- **WHEN** a client sends `GET /unknown`
- **THEN** the server SHALL respond with HTTP 404 Not Found
