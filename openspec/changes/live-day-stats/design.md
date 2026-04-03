## Context

StatsView loads data once on open and on parameter change. There is no periodic refresh. The menu bar already polls `readLatest()` every 60s via AppDelegate's timer, but Statistics uses `readRange()` for full-day data.

## Goals / Non-Goals

**Goals:**
- Day view of today auto-refreshes every 60 seconds
- Charts, summary cards, and alerts update in place

**Non-Goals:**
- Optimizing the refresh (appending single point instead of full reload) — full reload is fast enough for a single day (~160 readings)
- Refreshing week/month/year views — one new point every 5 min is invisible at that scale
- Push/SSE from server — polling is sufficient

## Decisions

### Timer.publish in SwiftUI

Use `Timer.publish(every: 60, on: .main, in: .common).autoconnect()` with `.onReceive`. Check if `granularity == .day` and `selectedDate` is today before reloading. Timer fires regardless but the guard clause makes it a no-op for other views.

**Why not NotificationCenter from AppDelegate**: Would require plumbing a new notification, and StatsView would still need to do a full `readRange` reload anyway. The timer is self-contained in StatsView with zero coupling to AppDelegate.

**Why not append-only**: `readRange` for a single day returns ~160 readings (~50KB over HTTP). On LAN this takes <100ms. The simplicity of full reload outweighs the marginal savings of append logic.

## Risks / Trade-offs

**[Trade-off] Full reload vs append** — Reloads all data every 60s instead of appending one point. Acceptable because a day's data is small and the code stays simple.

**[Risk] Stale timer on date change** — Timer fires every 60s regardless. The guard clause `Calendar.current.isDateInToday(selectedDate)` ensures it only reloads when viewing today. No risk of reloading past dates.
