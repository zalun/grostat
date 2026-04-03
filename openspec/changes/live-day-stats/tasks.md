## 1. Live Refresh

- [x] 1.1 Add `Timer.publish(every: 60)` with `.onReceive` to StatsView that calls `reloadData()` when `granularity == .day && Calendar.current.isDateInToday(selectedDate)`
- [ ] 1.2 Verify: open Statistics on today's day view, wait 60s, confirm chart updates with new data (manual)
- [ ] 1.3 Verify: switch to yesterday or week view, confirm no auto-reload occurs (manual)
