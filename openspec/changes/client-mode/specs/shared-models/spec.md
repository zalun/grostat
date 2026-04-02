## ADDED Requirements

### Requirement: Single InverterReading definition
The system SHALL have exactly one `InverterReading` struct defined in the `GrostatShared` SPM library target. Both `grostat` CLI and `GrostatBar` SHALL import this type instead of maintaining separate definitions.

#### Scenario: CLI uses shared type
- **WHEN** `grostat` CLI is built
- **THEN** it imports `InverterReading` from `GrostatShared` and uses it for API parsing and DB insertion

#### Scenario: GrostatBar uses shared type
- **WHEN** `GrostatBar` is built
- **THEN** it imports `InverterReading` from `GrostatShared` and uses it for SQLite reading and UI display

#### Scenario: Shared type includes all fields
- **WHEN** `InverterReading` is defined in `GrostatShared`
- **THEN** it SHALL contain the superset of all fields from both the CLI and GrostatBar versions (DC inputs, AC grid, temperatures, energy, diagnostics, computed fields)

### Requirement: InverterReading is Codable
The `InverterReading` struct SHALL conform to `Codable` for JSON serialization over the HTTP API.

#### Scenario: JSON round-trip
- **WHEN** an `InverterReading` is encoded to JSON and decoded back
- **THEN** all fields SHALL have identical values

### Requirement: ReadingProvider protocol
The system SHALL define a `ReadingProvider` protocol in `GrostatShared` with methods for reading inverter data.

#### Scenario: Protocol interface
- **WHEN** a type conforms to `ReadingProvider`
- **THEN** it SHALL implement `readLatest() -> InverterReading?` and `readRange(from: Date, to: Date) -> [InverterReading]`

### Requirement: Local package dependency
`GrostatBar/Package.swift` SHALL depend on the root package via `.package(path: "..")` to access `GrostatShared`. No additional build steps or install commands SHALL be required.

#### Scenario: Existing build commands unchanged
- **WHEN** user runs `just bar` or `cd GrostatBar && swift build -c release`
- **THEN** the build succeeds with the same commands as before, with SPM resolving the local dependency automatically
