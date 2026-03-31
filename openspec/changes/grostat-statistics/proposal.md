## Why

The menu bar popover shows only the latest inverter reading — there's no way to see trends, compare periods, or understand production patterns over time. Users need a dedicated analytics surface to answer questions like "how did this month compare to last month?" or "is my system producing less than the same time last year?" The data is already being collected in SQLite; it just needs a visualization layer.

## What Changes

- Add a "Statistics..." button to the existing popover that opens a dedicated statistics window
- New singleton NSWindow hosted in GrostatBar.app displaying two side-by-side comparison charts
- Extend StatusReader with time-range query capabilities (currently only reads latest reading)
- In-app aggregation of raw readings into day/hourly/daily/monthly granularity
- Period navigation with granularity picker (Day/Week/Month/Year), arrow stepping, and comparison presets
- Hover tooltips showing values for both primary and comparison periods
- Summary cards with hero metrics (total energy, peak power, delta %)
- All user selections (metrics, period, granularity) persisted in UserDefaults

## Capabilities

### New Capabilities
- `stats-window`: Singleton NSWindow lifecycle — open from popover, bring to front, close. AppDelegate integration.
- `stats-data-query`: Time-range SQLite queries and in-Swift aggregation (5-min/hourly/daily/monthly granularity).
- `stats-charts`: Two independent SwiftUI Charts with period comparison overlay, metric selection, catmullRom interpolation, hover tooltips.
- `stats-period-nav`: Granularity picker, arrow navigation, comparison presets (Previous Period, Same Period Last Year, Custom Range).
- `stats-summary-cards`: Hero metric cards (total energy, peak power, delta %) computed from queried data.

### Modified Capabilities
<!-- No existing specs to modify -->

## Impact

- **GrostatBar/Sources/AppDelegate.swift** — new window management, "Statistics..." button handler
- **GrostatBar/Sources/StatusPopover.swift** — add "Statistics..." button to popover
- **GrostatBar/Sources/StatusReader.swift** — extend with time-range query methods
- **New SwiftUI views** — StatsWindow, ChartView, PeriodSelector, SummaryCards, MetricPicker
- **Framework dependency** — SwiftUI Charts (system framework, no external deps)
- **Build** — GrostatBar Package.swift may need minimum deployment target adjustment for Charts API
