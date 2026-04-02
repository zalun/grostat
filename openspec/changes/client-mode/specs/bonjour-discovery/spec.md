## ADDED Requirements

### Requirement: Server advertises via Bonjour
When the HTTP server is running, it SHALL advertise itself as a `_grostat._tcp` service via mDNS/Bonjour.

#### Scenario: Service advertisement
- **WHEN** the HTTP server starts on port 7654
- **THEN** the app SHALL advertise a Bonjour service of type `_grostat._tcp` on that port with TXT record containing `device_sn` and `version`

#### Scenario: Advertisement stops with server
- **WHEN** the HTTP server stops (app quit or server disabled)
- **THEN** the Bonjour advertisement SHALL be removed

### Requirement: Client browses for servers
In client mode without a `server` config value, GrostatBar SHALL browse for `_grostat._tcp` services on the local network.

#### Scenario: Single server found
- **WHEN** the client discovers exactly one `_grostat._tcp` service
- **THEN** it SHALL auto-connect to that server without user interaction

#### Scenario: Multiple servers found
- **WHEN** the client discovers more than one `_grostat._tcp` service
- **THEN** it SHALL display a picker showing each server's `device_sn` (from TXT record) and hostname

#### Scenario: No servers found
- **WHEN** the client finds no `_grostat._tcp` services
- **THEN** the menu bar SHALL display a "Searching..." state and continue browsing

#### Scenario: Manual server config bypasses discovery
- **WHEN** the client config contains a `server` value (e.g., `"mac-studio.local:7654"`)
- **THEN** the client SHALL connect directly to that address without browsing Bonjour

### Requirement: Server picker UI
When multiple servers are discovered, the app SHALL present a SwiftUI picker view.

#### Scenario: Picker displays server info
- **WHEN** the picker is shown with discovered servers
- **THEN** each entry SHALL display the `device_sn` from the TXT record and the server hostname

#### Scenario: User selection is persisted
- **WHEN** the user selects a server from the picker
- **THEN** the chosen server's address SHALL be saved as `"server"` in the config file for automatic reconnection on next launch

### Requirement: Fallback on saved server failure
If the saved server becomes unreachable, the client SHALL fall back to Bonjour browsing.

#### Scenario: Saved server unreachable
- **WHEN** the client cannot connect to the saved `server` address after 3 attempts
- **THEN** it SHALL start Bonjour browsing as if no `server` was configured
