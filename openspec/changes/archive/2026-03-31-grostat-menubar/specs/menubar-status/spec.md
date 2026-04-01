## ADDED Requirements

### Requirement: Menu bar icon reflects inverter state
The app SHALL display an SF Symbol icon in the macOS menu bar that changes based on inverter state:
- `moon.zzz` — sleep (status=0 or no recent data)
- `sun.max.fill` — producing (ppv > 0, below on-fire threshold)
- `bolt.fill` — on fire (ppv ≥ 70% of rated_power_w)
- `exclamationmark.triangle.fill` — fault (status=3)
- `questionmark.circle` — offline (no data or DB missing)

#### Scenario: Inverter producing normally
- **WHEN** latest reading has status=1 and ppv=3200 and rated_power_w=10000
- **THEN** menu bar SHALL show `sun.max.fill` icon (3200 < 7000 threshold)

#### Scenario: Inverter on fire
- **WHEN** latest reading has ppv=8500 and rated_power_w=10000
- **THEN** menu bar SHALL show `bolt.fill` icon (8500 ≥ 7000 threshold)

#### Scenario: Inverter sleeping
- **WHEN** latest reading has status=0 or ppv=0
- **THEN** menu bar SHALL show `moon.zzz` icon

#### Scenario: Inverter fault
- **WHEN** latest reading has status=3
- **THEN** menu bar SHALL show `exclamationmark.triangle.fill` icon

#### Scenario: No data available
- **WHEN** database has no readings or DB file is missing
- **THEN** menu bar SHALL show `questionmark.circle` icon

### Requirement: Menu bar text shows power with voltage-colored text
The app SHALL display current DC power (ppv) in kW next to the icon, with text color indicating grid voltage status:
- Green: vmax_phase < 250V
- Orange: vmax_phase ≥ 250V and < 253V
- Red: vmax_phase ≥ 253V

When inverter is sleeping or offline, no power text SHALL be shown (icon only).

#### Scenario: Normal voltage
- **WHEN** ppv=3200 and vmax_phase=248.5
- **THEN** menu bar SHALL show "3.2kW" in green text

#### Scenario: Warning voltage
- **WHEN** ppv=5000 and vmax_phase=251.2
- **THEN** menu bar SHALL show "5.0kW" in orange text

#### Scenario: Critical voltage
- **WHEN** ppv=8000 and vmax_phase=253.5
- **THEN** menu bar SHALL show "8.0kW" in red text

#### Scenario: Sleeping
- **WHEN** status=0
- **THEN** menu bar SHALL show icon only, no power text

### Requirement: Refresh every 60 seconds
The app SHALL read the latest row from SQLite database every 60 seconds and update the menu bar icon and text.

#### Scenario: Regular refresh
- **WHEN** 60 seconds have passed since last read
- **THEN** the app SHALL query the database for the latest reading and update display

### Requirement: Stale data indicator
The app SHALL dim the icon or show reduced opacity when the latest reading is older than 10 minutes.

#### Scenario: Fresh data
- **WHEN** latest reading timestamp is less than 10 minutes ago
- **THEN** the icon and text SHALL be displayed at full opacity

#### Scenario: Stale data
- **WHEN** latest reading timestamp is more than 10 minutes ago
- **THEN** the icon and text SHALL be displayed at reduced opacity (50%)
