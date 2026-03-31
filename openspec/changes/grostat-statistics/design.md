## Context

GrostatBar is a macOS menu bar app (AppKit + SwiftUI) that displays real-time inverter status in a popover. The `grostat` CLI collects readings every 5 minutes into a SQLite database (`~/.local/share/grostat/grostat.db`). The statistics window adds a second UI surface — an NSWindow with SwiftUI content — for viewing historical data with period comparisons.

The app currently uses: NSStatusBar, NSPopover, NSHostingController for SwiftUI embedding, and direct SQLite3 C API calls via StatusReader. The design system is defined in `.impeccable.md`.

## Goals / Non-Goals

**Goals:**
- Period comparison as the primary interaction model (not an add-on)
- Two independent charts, each with its own metric selector
- Smooth, delightful charting following `.impeccable.md` design principles
- All selections persisted across app restarts (UserDefaults)
- Clean data flow: SQLite → Swift aggregation → SwiftUI Charts

**Non-Goals:**
- Real-time/live updating of charts (this is historical analysis)
- Zoom, drill-down, or interactive range selection
- Data export or sharing
- Multiple statistics windows open simultaneously
- Current inverter status display (stays in popover)

## Decisions

### 1. Singleton NSWindow with SwiftUI content

**Choice:** One NSWindow instance managed by AppDelegate, hosting a SwiftUI view hierarchy via NSHostingController.

**Why:** Matches the existing pattern (NSPopover + NSHostingController). Singleton avoids state confusion — "Statistics..." button toggles visibility or brings to front.

**Alternative considered:** Pure SwiftUI WindowGroup — rejected because GrostatBar is an AppKit-lifecycle app (NSApplication + AppDelegate), and mixing in SwiftUI app lifecycle would add complexity for no benefit.

### 2. Aggregation in Swift, not SQL

**Choice:** Fetch raw readings for the selected time range with a simple `SELECT * FROM readings WHERE timestamp BETWEEN ? AND ? ORDER BY timestamp`, then aggregate in Swift.

**Why:** The dataset is small (5-min intervals = ~105K rows/year max, typical queries return hundreds to low thousands of rows). Swift aggregation gives full control over gap handling, alignment for comparison periods, and feeding data directly to SwiftUI Charts. No need for complex SQL GROUP BY + strftime logic.

**Alternative considered:** SQL-level aggregation — more efficient for large datasets, but adds query complexity and makes comparison period alignment harder. Not needed at this data scale.

### 3. Gap handling: skip, don't interpolate

**Choice:** When readings are missing (night, computer off, network down), simply omit those data points from the chart series. SwiftUI Charts with catmullRom interpolation will draw smooth lines between existing points.

**Why:** Filling gaps with zeros or interpolated values would misrepresent reality. A gap in the line naturally communicates "no data here." The user explicitly confirmed this approach.

### 4. Auto-granularity tied to view period

**Choice:** Fixed mapping — Day→5min, Week→hourly, Month→daily, Year→monthly. No user-configurable granularity.

**Why:** Keeps chart density reasonable (max ~170 data points per chart). User selects "what period to look at," the app decides the appropriate level of detail. Simpler UI, fewer controls.

### 5. Comparison period alignment

**Choice:** Both primary and comparison periods use the same granularity and are aligned by offset within the period. For example, comparing March vs February: March 15 daily value aligns with February 15 daily value. If February has fewer days, those points are simply absent.

**Why:** Direct alignment makes visual comparison intuitive — same x-position = same relative point in the period.

### 6. Data flow architecture

```
UserDefaults (persisted selections)
       │
       ▼
┌─────────────┐    ┌──────────────┐    ┌─────────────┐
│ PeriodState  │───▶│ StatsDataMgr │───▶│ ChartData   │
│ (ObsObject)  │    │ (aggregation)│    │ (view model) │
└─────────────┘    └──────┬───────┘    └─────────────┘
                          │
                   ┌──────▼───────┐
                   │ StatusReader  │
                   │ (SQLite)     │
                   └──────────────┘
```

- **PeriodState** (ObservableObject): Holds current granularity, selected date, comparison mode. Reads/writes UserDefaults. Published properties trigger re-query.
- **StatsDataManager**: Takes a time range, queries StatusReader, aggregates readings, produces ChartData for both primary and comparison periods.
- **ChartData**: Struct containing data points for both lines, plus computed summary metrics (total energy, peak power, delta %).

### 7. Metric definitions

Each metric maps to one or more InverterReading fields and defines how to aggregate:

| Metric | Fields | Aggregation | Unit |
|--------|--------|-------------|------|
| Energy | powerToday | last value per bucket (cumulative) | kWh |
| Power DC | ppv | average | kW |
| Power AC | pac | average | kW |
| Voltage | vmaxPhase | max | V |
| Temperature | temperature | max | °C |
| Power/String | ppv1, ppv2 | average (two lines) | kW |

"Power per string" is special — it shows ppv1 vs ppv2 as two lines within the same chart (both for primary period, no comparison overlay for this metric).

## Risks / Trade-offs

**[SwiftUI Charts minimum deployment target]** → Charts requires macOS 13+. Check current deployment target in Package.swift; may need to bump. Low risk since the app already uses modern SwiftUI features.

**[First query on large database could be slow]** → A year of data at 5-min intervals is ~105K rows. Even reading all of them into memory is fast (< 100ms on any modern Mac). Not a real concern unless collection runs for many years. → Could add LIMIT as a safety valve if needed later.

**[UserDefaults for persistence]** → Simple and appropriate for UI preferences. No migration needed. If the app were sandboxed, UserDefaults would be scoped to the app container, which is fine.

**[Custom Range comparison]** → The "Custom Range" preset in the comparison dropdown needs a date picker UI. This is the most complex comparison mode. → Start with Previous Period and Same Period Last Year; Custom Range can be added as a follow-up if the first two cover 90% of use cases.
