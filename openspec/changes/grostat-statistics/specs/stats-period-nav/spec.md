## ADDED Requirements

### Requirement: Granularity picker
The statistics window SHALL have a granularity picker with options: Day, Week, Month, Year.

#### Scenario: Select granularity
- **WHEN** user selects "Month" from the granularity picker
- **THEN** the period label updates (e.g., "March 2026"), data is re-aggregated to daily granularity, and charts re-render

### Requirement: Arrow navigation
The statistics window SHALL have back/forward arrow buttons to step through periods.

#### Scenario: Step forward one month
- **WHEN** granularity is "Month", current period is "March 2026", and user clicks forward arrow
- **THEN** the period changes to "April 2026" and charts update

#### Scenario: Step back one day
- **WHEN** granularity is "Day", current period is "2026-03-15", and user clicks back arrow
- **THEN** the period changes to "2026-03-14" and charts update

### Requirement: Period label format adapts to granularity
The period label SHALL display the current period in a format appropriate to the granularity.

#### Scenario: Day format
- **WHEN** granularity is "Day"
- **THEN** the label shows the date (e.g., "2026-03-15")

#### Scenario: Week format
- **WHEN** granularity is "Week"
- **THEN** the label shows the week range (e.g., "Mar 9 – 15, 2026")

#### Scenario: Month format
- **WHEN** granularity is "Month"
- **THEN** the label shows month and year (e.g., "March 2026")

#### Scenario: Year format
- **WHEN** granularity is "Year"
- **THEN** the label shows the year (e.g., "2026")

### Requirement: Comparison mode selector
The statistics window SHALL have a dropdown to select comparison mode.

#### Scenario: Available comparison presets
- **WHEN** user opens the comparison dropdown
- **THEN** the options are: Previous Period, Same Period Last Year, Custom Range

#### Scenario: Previous Period selected
- **WHEN** comparison mode is "Previous Period" and primary is March 2026 (Month)
- **THEN** the comparison period is February 2026

#### Scenario: Same Period Last Year selected
- **WHEN** comparison mode is "Same Period Last Year" and primary is March 2026 (Month)
- **THEN** the comparison period is March 2025

### Requirement: All navigation state persisted
Granularity, comparison mode, and current period SHALL be persisted in UserDefaults.

#### Scenario: State restored on reopen
- **WHEN** user closes and reopens the statistics window (or restarts the app)
- **THEN** granularity, period, and comparison mode are restored to their previous values
