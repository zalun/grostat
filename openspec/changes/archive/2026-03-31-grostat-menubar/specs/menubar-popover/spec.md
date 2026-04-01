## ADDED Requirements

### Requirement: Click opens status popover
The app SHALL show a popover panel when the menu bar icon/text is clicked. The popover SHALL display the latest inverter reading grouped by category.

#### Scenario: Click to open
- **WHEN** user clicks the menu bar icon
- **THEN** a popover SHALL appear showing the full inverter status

#### Scenario: Click to close
- **WHEN** popover is open and user clicks the icon again or clicks outside
- **THEN** the popover SHALL close

### Requirement: Popover displays grouped inverter data
The popover SHALL show the latest reading organized in sections:
- **Header**: device SN, last update timestamp, status badge
- **DC Input**: vpv1/2, ipv1/2, ppv1/2, ppv, epv1/2 today
- **AC Grid**: phase voltages, currents, power per phase, pac, pf, fac
- **Temperature**: inverter, IPM
- **Energy**: today, total
- **Diagnostics**: status, faults, warnings, bus voltages

#### Scenario: Full data display
- **WHEN** popover is opened and database has readings
- **THEN** all sections SHALL be populated with values from the latest reading

#### Scenario: No data
- **WHEN** popover is opened and database is empty
- **THEN** popover SHALL show "No data. Is 'grostat collect' running?"

### Requirement: Popover has quit option
The popover SHALL include a "Quit" button or menu item to exit the app.

#### Scenario: Quit
- **WHEN** user clicks "Quit" in the popover
- **THEN** the app SHALL terminate
