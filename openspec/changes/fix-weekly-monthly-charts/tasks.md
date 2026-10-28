# Tasks

## 1. Add `granularity` property to `StatsChartView`

**File:** `GrostatBar/Sources/StatsChartView.swift`

Add `let granularity: Granularity` property.

## 2. Conditionally skip gap segmentation

**File:** `GrostatBar/Sources/StatsChartView.swift`

In `primaryMarks`, `comparisonMarks`, and `powerPerStringMarks`: when `granularity != .day`, pass all points as a single segment instead of calling `segmentsByGap`.

## 3. Update call sites in StatsView

**File:** `GrostatBar/Sources/StatsView.swift`

Pass `periodState.granularity` to `StatsChartView`.
