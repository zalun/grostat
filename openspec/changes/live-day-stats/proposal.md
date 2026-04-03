## Why

The Statistics window shows a static snapshot loaded once. When viewing today's day chart, you have to close and reopen Statistics to see new data points. Since `grostat collect` adds a new reading every 5 minutes, the day chart should grow in real time without user interaction.

## What Changes

- **Auto-refresh for today's day view** — when Statistics is open on today's date with `Day` granularity, data reloads automatically every 60 seconds. Other views (week/month/year) and past dates remain static.

## Capabilities

### New Capabilities
- `live-day-refresh`: Automatic periodic refresh of the Statistics day view when showing today's data

### Modified Capabilities

_(none)_

## Impact

- **GrostatBar/Sources/StatsView.swift** — add Timer.publish that triggers `reloadData()` every 60s, gated on `granularity == .day && selectedDate == today`
