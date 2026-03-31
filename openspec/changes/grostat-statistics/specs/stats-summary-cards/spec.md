## ADDED Requirements

### Requirement: Summary cards displayed above charts
The statistics window SHALL display summary cards between the period selector and the charts.

#### Scenario: Card layout
- **WHEN** the statistics window is open
- **THEN** summary cards are displayed in a horizontal row above the two charts

### Requirement: Total Energy card
A summary card SHALL show total energy produced in the primary period.

#### Scenario: Total energy display
- **WHEN** the primary period is March 2026 (Month view)
- **THEN** the Total Energy card shows the sum of daily energy values (kWh) for March 2026

### Requirement: Peak Power card
A summary card SHALL show the peak power reading in the primary period.

#### Scenario: Peak power display
- **WHEN** the primary period has data
- **THEN** the Peak Power card shows the highest PAC value (kW) recorded in the period

### Requirement: Delta percentage card
A summary card SHALL show the percentage change between primary and comparison periods.

#### Scenario: Positive delta
- **WHEN** primary total energy is 342.5 kWh and comparison total energy is 305.0 kWh
- **THEN** the Delta card shows "+12.3%"

#### Scenario: Negative delta
- **WHEN** primary total energy is lower than comparison
- **THEN** the Delta card shows a negative percentage (e.g., "-8.2%")

#### Scenario: No comparison data
- **WHEN** the comparison period has no data
- **THEN** the Delta card shows "—" or is hidden

### Requirement: Cards use hero metric styling
Summary cards SHALL use large, bold numbers with monospaced digits following .impeccable.md typography.

#### Scenario: Visual styling
- **WHEN** summary cards are rendered
- **THEN** the primary value is displayed in large bold text with monospaced digits, the label is in uppercase caption style, and the card has subtle elevation
