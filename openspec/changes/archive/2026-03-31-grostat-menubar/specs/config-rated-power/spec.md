## ADDED Requirements

### Requirement: rated_power_w config field
The config (`~/.config/grostat/config.json`) SHALL support a `rated_power_w` field (integer, default 10000) representing the inverter's rated power in watts.

#### Scenario: Default value
- **WHEN** config file has no `rated_power_w` field
- **THEN** the system SHALL use 10000 as default

#### Scenario: Custom value
- **WHEN** config file has `"rated_power_w": 8000`
- **THEN** the system SHALL use 8000 for threshold calculations

### Requirement: On-fire threshold is 70% of rated power
The "on fire" state SHALL be triggered when ppv ≥ 0.7 * rated_power_w.

#### Scenario: Default 10kW inverter
- **WHEN** rated_power_w=10000 and ppv=7500
- **THEN** the system SHALL consider this "on fire" (7500 ≥ 7000)

#### Scenario: Smaller inverter
- **WHEN** rated_power_w=5000 and ppv=3600
- **THEN** the system SHALL consider this "on fire" (3600 ≥ 3500)
