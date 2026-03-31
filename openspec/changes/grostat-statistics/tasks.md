## 1. Data Layer

- [x] 1.1 Extend StatusReader with a time-range query method: `func readRange(from: Date, to: Date) -> [InverterReading]`
- [x] 1.2 Create StatsDataManager that takes a time range + granularity, queries StatusReader, and aggregates readings into buckets (5min/hourly/daily/monthly)
- [x] 1.3 Define Metric enum with aggregation logic per metric (Energy: last, Power DC/AC: avg, Voltage: max, Temperature: max, Power/String: avg of ppv1+ppv2)
- [x] 1.4 Add comparison period calculation: given primary range + comparison mode, compute the comparison date range
- [x] 1.5 Create ChartData struct holding primary + comparison data point arrays and computed summary metrics (total energy, peak power, delta %)

## 2. Window & Navigation

- [x] 2.1 Create singleton NSWindow in AppDelegate with NSHostingController hosting the root StatsView
- [x] 2.2 Add "Statistics..." button to StatusPopover that calls AppDelegate to show/bring-to-front the stats window
- [x] 2.3 Create PeriodState ObservableObject: granularity, selectedDate, comparisonMode — reads/writes UserDefaults on change
- [x] 2.4 Build PeriodSelector view: granularity picker (Day/Week/Month/Year), back/forward arrows, period label (format adapts to granularity), comparison mode dropdown

## 3. Charts

- [x] 3.1 Create StatsChartView using SwiftUI Charts: solid catmullRom line (solar gold) + area fill (10% opacity) for primary, dashed catmullRom line (cool blue) for comparison
- [x] 3.2 Add hover interaction: vertical rule + tooltip showing both period values at the hovered x-position
- [x] 3.3 Add metric dropdown per chart, persisted in UserDefaults (left chart + right chart independent)
- [x] 3.4 Handle "Power per String" special case: show ppv1 vs ppv2 as two lines instead of primary/comparison overlay

## 4. Summary Cards

- [x] 4.1 Create SummaryCardsView with three cards: Total Energy (kWh), Peak Power (kW), Delta (%)
- [x] 4.2 Style cards per .impeccable.md: large bold monospaced digits, uppercase caption labels, subtle elevation

## 5. Layout & Polish

- [x] 5.1 Compose root StatsView: PeriodSelector → SummaryCards → two StatsChartViews side by side
- [x] 5.2 Apply .impeccable.md styling: SF Pro, generous padding (16-20pt), system dark/light mode, minimal grid lines
- [x] 5.3 Set appropriate window min size, default size, and title ("Statistics")
- [ ] 5.4 Verify chart rendering with real data across all four granularities
