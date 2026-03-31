## ADDED Requirements

### Requirement: Time-range query from SQLite
StatusReader SHALL support querying readings within a specified time range.

#### Scenario: Query readings for a date range
- **WHEN** a time range (start, end) is provided
- **THEN** all readings with timestamps within that range are returned, ordered by timestamp ascending

#### Scenario: No readings in range
- **WHEN** a time range is queried that has no readings
- **THEN** an empty array is returned

### Requirement: In-Swift aggregation by granularity
The system SHALL aggregate raw readings into buckets based on the selected granularity.

#### Scenario: 5-minute granularity (day view)
- **WHEN** granularity is "day"
- **THEN** readings are returned at their original 5-minute intervals (no aggregation)

#### Scenario: Hourly aggregation (week view)
- **WHEN** granularity is "week"
- **THEN** readings are averaged into 1-hour buckets

#### Scenario: Daily aggregation (month view)
- **WHEN** granularity is "month"
- **THEN** readings are aggregated into daily values (energy: last value per day, power/voltage/temp: average or max per metric definition)

#### Scenario: Monthly aggregation (year view)
- **WHEN** granularity is "year"
- **THEN** readings are aggregated into monthly values

### Requirement: Comparison period data
The system SHALL query and aggregate data for both the primary and comparison periods.

#### Scenario: Previous period comparison
- **WHEN** comparison mode is "Previous Period" and primary is March 2026 (month view)
- **THEN** the system also queries February 2026 with the same granularity

#### Scenario: Same period last year comparison
- **WHEN** comparison mode is "Same Period Last Year" and primary is March 2026
- **THEN** the system also queries March 2025 with the same granularity

### Requirement: Data points aligned by offset
Primary and comparison data points SHALL be aligned by their relative position within the period.

#### Scenario: Month comparison alignment
- **WHEN** comparing March 2026 vs February 2026 (daily granularity)
- **THEN** day 1 of March aligns with day 1 of February on the x-axis, and February's shorter length simply has fewer points

### Requirement: Gaps are preserved
Missing data points SHALL not be filled or interpolated at the data layer.

#### Scenario: Computer was off for 3 hours
- **WHEN** no readings exist between 10:00 and 13:00
- **THEN** the aggregated data contains no entries for that time span
