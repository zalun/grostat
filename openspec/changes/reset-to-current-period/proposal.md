# Reset to Current Period on Popover Open

## Problem

When the popover opens, it shows the last-viewed date (persisted in UserDefaults). If you checked stats yesterday and open the popover today, you still see yesterday's data. The natural expectation is to see the current period.

## Solution

When the popover opens, automatically reset `selectedDate` to today if the stored date falls outside the current period for the active granularity:

| Granularity | Reset if selectedDate is... |
|-------------|---------------------------|
| `.day`      | not today                  |
| `.week`     | not in current ISO week    |
| `.month`    | not in current month       |
| `.year`     | not in current year        |

The detached stats window does **not** reset — it's for exploration. Only the popover resets.

## Scope

- Add `resetToCurrentPeriodIfNeeded()` method to `PeriodState`
- Call it in `AppDelegate.showStatsPopover()` before building the view
