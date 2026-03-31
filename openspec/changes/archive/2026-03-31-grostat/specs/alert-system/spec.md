## ADDED Requirements

### Requirement: Two-tier voltage alerts
The system SHALL evaluate the maximum phase voltage (`vmax_phase`) against two thresholds after each reading:
- **WARNING**: vmax_phase ≥ 250.0V
- **CRITICAL**: vmax_phase ≥ 253.0V

Both thresholds SHALL be configurable via environment variables.

#### Scenario: Normal voltage
- **WHEN** vmax_phase = 248.5V
- **THEN** the system SHALL log the reading at INFO level with no alert

#### Scenario: Warning threshold
- **WHEN** vmax_phase = 251.2V (≥250V, <253V)
- **THEN** the system SHALL log at WARNING level and store alert="WARNING" in the database

#### Scenario: Critical threshold
- **WHEN** vmax_phase = 253.5V (≥253V)
- **THEN** the system SHALL log at CRITICAL level and store alert="CRITICAL" in the database

### Requirement: macOS desktop notifications
The system SHALL send a macOS notification via `osascript` when an alert is triggered. To avoid notification spam, the system SHALL send at most one notification per alert level per `grostat collect` invocation.

#### Scenario: First WARNING in session
- **WHEN** a WARNING alert is detected during `grostat collect`
- **THEN** the system SHALL display a macOS notification with title "grostat" and message containing the voltage and phase

#### Scenario: CRITICAL notification
- **WHEN** a CRITICAL alert is detected during `grostat collect`
- **THEN** the system SHALL display a macOS notification with title "grostat CRITICAL" and message containing the voltage value

#### Scenario: Non-macOS environment
- **WHEN** the system is not running on macOS (or `osascript` is unavailable)
- **THEN** the system SHALL skip the notification silently and rely on log output only
