# Tasks

## Phase 1: Server + shared model

### 1.1 Add `PeriodSummary` to GrostatShared
- [x] Create `Sources/GrostatShared/PeriodSummary.swift`
- [x] Fields: periodStart (String), totalEnergy, peakPowerAC, peakPowerDC, peakVoltage, maxTemperature, peakPpv1, peakPpv2 (all Double)
- [x] Codable, date parsed via computed `date` property

### 1.2 Add summary aggregation to StatusReader
- [x] Add `readDailySummaries(from:to:) -> [PeriodSummary]` to ReadingProvider protocol
- [x] Implement in StatusReader: query raw readings, group by day, compute max/sum per day
- [x] Energy per day: max powerToday after last reset
- [x] Implement in RemoteReader: calls /summary/daily

### 1.3 Add server endpoints
- [x] `/summary/daily?from=&to=` — calls readDailySummaries, returns JSON
- [x] `/summary/weekly?from=&to=` — aggregates daily summaries into ISO weeks
- [x] `/summary/monthly?from=&to=` — aggregates daily summaries into months
- [x] Remove old `/readings/daily` endpoint
- [x] RemoteReader.readRange always uses /readings (no more daily hack)

## Phase 2: Client data layer

### 2.1 Update Granularity enum
- [x] Replace `.year` with `.yearWeekly` and `.yearMonthly`
- [x] Update `calendarComponent`, `label` for new cases
- [x] Add `usesSummaries` and `summaryEndpoint` properties
- [x] Update `PeriodRange.primary()` for yearWeekly/yearMonthly
- [x] PeriodState: old "year" falls back to `.day` gracefully

### 2.2 Update Metric enum
- [x] Add summary metrics: `.peakPower`, `.peakVoltage`, `.peakTemp`
- [x] Add `dayMetrics` / `summaryMetrics` / `metrics(for:)` static methods

### 2.3 Update StatsDataManager
- [x] Split `load()` into `loadDay()` and `loadSummary()`
- [x] `loadSummary` fetches via RemoteReader.fetchSummaries or local aggregation
- [x] `summaryDataPoints()` maps PeriodSummary → DataPoint per metric
- [x] Summary cards use summary-derived totals
- [x] Local mode: `aggregateLocal()` for yearWeekly/yearMonthly

### 2.4 Update PeriodState + PeriodSelector
- [x] `periodLabel` handles `.yearWeekly`/`.yearMonthly`
- [x] Picker width adjusted for longer labels

### 2.5 Update StatsView
- [x] Metric picker shows only `availableMetrics` for current granularity
- [x] `adjustMetricsForGranularity()` auto-switches on granularity change

## Phase 3: UI

### 3.1 Update StatsChartView for summaries
- [x] Gap segmentation skipped for non-day views (done in earlier change)
- [ ] Consider BarMark for summary views (currently LineMark)
- [ ] Comparison overlay for summary charts (already works via rebase)

### 3.2 Update SummaryCardsView
- [x] Works with ChartData from summary path (totalEnergy, peakPower already populated)
