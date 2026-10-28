# Tasks: Stats in Popover

- [x] Create PopoverContentView with tab enum (.statistics/.status) and tab bar UI
- [x] Create StatsPopoverView that wraps StatsView content with [↗] detach button
- [x] Move PeriodState and StatsDataManager creation to AppDelegate (shared state)
- [x] Update togglePopover() to show PopoverContentView, default to Statistics at 820×520
- [x] Add popover size animation when switching tabs (820×520 ↔ 320×480)
- [x] Wire [↗] detach: open NSWindow with same PeriodState, close popover
- [x] Remove "Statistics" button from StatusPopover
- [x] Build and test
