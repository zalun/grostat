# Spec: Popover Statistics

## Requirements

1. Clicking menu bar icon opens popover with Statistics view at 820×520
2. Tab bar at top: [Statistics] [Status] — Statistics selected by default
3. Switching to Status tab animates popover to 320×480
4. Switching to Statistics tab animates popover to 820×520
5. [↗] detach button opens full NSWindow (900×700) with same PeriodState
6. Detaching closes the popover
7. StatsView content identical in popover and window (same charts, summary, alerts)
8. "Statistics" button removed from StatusPopover (tab replaces it)
9. Quit button remains in Status tab
