## ADDED Requirements

### Requirement: Auto-refresh today's day view
The Statistics window SHALL automatically reload data every 60 seconds when the selected granularity is `Day` and the selected date is today.

#### Scenario: Viewing today
- **WHEN** Statistics is open with granularity `Day` and selectedDate is today
- **THEN** data SHALL reload every 60 seconds, updating charts, summary cards, and alerts

#### Scenario: Viewing a past date
- **WHEN** Statistics is open with granularity `Day` and selectedDate is not today
- **THEN** no automatic reload SHALL occur

#### Scenario: Viewing week/month/year
- **WHEN** Statistics is open with any granularity other than `Day`
- **THEN** no automatic reload SHALL occur

#### Scenario: Switching to today
- **WHEN** the user changes the selected date to today while granularity is `Day`
- **THEN** auto-refresh SHALL begin within 60 seconds
