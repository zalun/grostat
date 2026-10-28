# Fix empty charts in week/month/year views

## Problem

Charts appear empty in week, month, and year granularities. Data loads correctly (summary cards show values), but `segmentsByGap` in `StatsChartView` uses a fixed `maxGapSeconds = 900` (15 min). Aggregated data points are spaced hourly (week), daily (month), or monthly (year) — all exceeding 900s — so every point becomes its own 1-point segment, which draws no visible line.

## Solution

Pass `granularity` to `StatsChartView` and skip gap detection for non-day views. For week/month/year, all points form a single continuous line since aggregation already smooths the data.

## Scope

- Add `granularity` parameter to `StatsChartView`
- In `primaryMarks`, `comparisonMarks`, and `powerPerStringMarks`: use `segmentsByGap` only for `.day`, otherwise treat all points as one segment
- Update call sites in `StatsView` to pass `granularity`
