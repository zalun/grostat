# Design: Stats in Popover

## Architecture

### Current flow
1. Click menu bar → NSPopover (320×480) with StatusPopover
2. Click "Statistics" button → popover closes, NSWindow (900×700) opens with StatsView

### New flow
1. Click menu bar → NSPopover (820×520) with Statistics (default tab)
2. Click [Status] tab → popover animates to 320×480 with StatusPopover
3. Click [↗] → NSWindow (900×700) opens with same state, popover closes

## Key Components

### PopoverContentView (new)
- Root view inside the popover
- Manages tab state: `.statistics` (default) | `.status`
- Controls popover size via binding to AppDelegate

### StatsPopoverView (new, wraps StatsView)
- Adapted version of StatsView for popover context
- Same two charts side-by-side, summary cards, period selector, alerts
- Adds [↗] detach button
- Frame: 820×520

### TabBar (new)
- Simple [Statistics] [Status] toggle at top
- Minimal styling, consistent with .impeccable.md design system

### AppDelegate changes
- `togglePopover()`: opens Statistics tab by default (820×520)
- `popover.contentSize` animates when switching tabs
- `showStatsWindow()` receives PeriodState from popover to preserve state
- Remove "Statistics" button from StatusPopover (replaced by tab)

## Decisions

1. **No @AppStorage for tab state** — always open on Statistics
2. **PeriodState shared** between popover and window via reference
3. **StatsDataManager** created once in AppDelegate, shared with both popover and window
4. **Quit button** stays in StatusPopover (Status tab)
