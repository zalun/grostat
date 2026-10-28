# Period Summaries — proper weekly/monthly/yearly charts

## Problem

Weekly, monthly, and yearly views try to chart raw `InverterReading` snapshots aggregated client-side. The `/readings/daily` endpoint picks one reading per day (max powerToday), but that reading's instantaneous metrics (ppv, pac, voltage) are from a single moment (usually end of day when power is near zero). Charts appear empty or misleading.

More fundamentally: non-day views answer different questions than the day view. Day = "how did production look today?" (time series). Week/month/year = "how did each period compare?" (discrete summaries).

## Solution

### New shared model: `PeriodSummary`

One type for all summary granularities (daily, weekly, monthly):

```
PeriodSummary {
    periodStart: Date
    totalEnergy: Double       // kWh (sum of daily maxes)
    peakPowerAC: Double       // kW (max pac in period)
    peakPowerDC: Double       // kW (max ppv)
    peakVoltage: Double       // V (max vmaxPhase)
    maxTemperature: Double    // °C
    peakPpv1: Double          // kW
    peakPpv2: Double          // kW
}
```

### Server endpoints

Replace `/readings/daily` with three summary endpoints:

| Endpoint | Groups by | Used for |
|----------|-----------|----------|
| `/summary/daily?from=&to=` | day | week, month views |
| `/summary/weekly?from=&to=` | ISO week | year-weekly view |
| `/summary/monthly?from=&to=` | month | year-monthly view |

All return `[PeriodSummary]`.

### Granularity enum changes

```
.day         → /readings (raw InverterReading, as today)
.week        → /summary/daily
.month       → /summary/daily
.yearWeekly  → /summary/weekly
.yearMonthly → /summary/monthly
```

Picker: `[ Day | Week | Month | Year-W | Year-M ]`

### Chart changes

- Day view: unchanged (LineMark, raw time series)
- Week/month/year: new chart rendering using `PeriodSummary` data
- Available metrics for summary views: Energy, Peak Power, Peak Voltage, Peak Temp
- Chart type: BarMark or LineMark+PointMark (TBD during implementation)
- Comparison period: works the same, just compares summary arrays

### Summary cards

- Day: totalEnergy from powerToday, peakPower from max pac (unchanged)
- Week/month/year: totalEnergy = sum of daily energies, peakPower = max of daily peaks

## Scope

### Phase 1: Server + shared model
- Add `PeriodSummary` to GrostatShared
- Add `/summary/daily`, `/summary/weekly`, `/summary/monthly` to GrostatServer
- Remove old `/readings/daily`

### Phase 2: Client data layer
- Update `RemoteReader` with `readSummaries(from:to:granularity:)` returning `[PeriodSummary]`
- Update `Granularity` enum (add `.yearWeekly`, `.yearMonthly`, remove `.year`)
- Update `StatsDataManager.load()` to use summaries for non-day views
- New `SummaryChartData` (or adapt `ChartData`) for summary-based views

### Phase 3: UI
- Update `PeriodSelector` picker labels
- Update `StatsChartView` for summary rendering
- Update `SummaryCardsView` to handle summary data
- Update `PeriodState` persistence for new granularity values
