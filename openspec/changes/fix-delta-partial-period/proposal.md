# Fix delta comparison for partial periods

## Problem

When viewing a week that's still in progress (e.g., Monday-Thursday of current week), the DELTA percentage compares partial current period energy against the **full** previous period. This makes the delta misleadingly negative — showing -29.9% when the real trend might be flat or positive.

```
Current:    Apr 6-10  (4 days) = 141.5 kWh
Comparison: Mar 30-5  (7 days) = ~200 kWh
Delta:      -29.9%  (misleading)
```

Same issue applies to partial months and partial years.

## Solution

When computing delta, only sum comparison summaries up to the same number of entries as the primary period. This gives an apples-to-apples comparison:

```
Current:    Apr 6-10  (4 days) = 141.5 kWh
Comparison: Mar 30-2  (4 days) = ~120 kWh  (trimmed to match)
Delta:      +17.9%  (accurate)
```

## Scope

- `StatsData.swift` `loadSummary()` — trim `comparisonSummaries` to `primarySummaries.count` before computing `compTotalEnergy` and `compPeakPower`
- Summary cards only — chart bars stay as-is (showing full comparison period is useful visual context)

## Non-scope

- Chart rendering (bars already behave correctly)
- Day view delta (uses raw readings, different logic)
