# Stats in Popover

## Summary

Move Statistics view from a separate NSWindow into the menu bar popover as the default view. Clicking the menu bar icon opens an 820×520 popover with full Statistics (period selector, summary cards, two charts, alerts). Status becomes a secondary tab. A detach button [↗] opens the current full NSWindow (900×700) for deeper analysis.

## Motivation

- Opening Statistics requires two steps: click menu bar → click "Statistics" button → separate window opens. This feels clunky.
- Statistics is the primary use case — checking daily production, comparing periods. It should be one click away.
- Status (live reading) is already visible in the menu bar icon, making the StatusPopover secondary.

## Scope

### In scope
- Replace default popover content with Statistics view (two charts side-by-side, summary cards, period selector, alerts)
- Add tab bar: [Statistics] [Status] — Statistics is default
- Animate popover size: 820×520 for Statistics, 320×480 for Status
- Add [↗] detach button that opens full NSWindow and closes popover
- Preserve state when detaching (same date, metrics, comparison mode)
- Keep NSWindow as-is for full analysis mode

### Out of scope
- Redesigning StatusPopover content
- Removing StatusPopover (keeping it as tab — will evaluate usage later)
- Changing Statistics data/chart logic
- Mobile or other platform considerations

## Design

```
┌─ Default: Statistics (820×520) ─────────────────────────────────┐
│  [Statistics] [Status]                                    [↗]   │
├─────────────────────────────────────────────────────────────────┤
│  ◀  2026-04-04                     Day ▾   vs Yesterday ▾   ▶  │
├─────────────────────────────────────────────────────────────────┤
│   12.4 kWh        3.8 kW peak        +5.2%        4h 32m      │
├─────────────────────────────────────────────────────────────────┤
│  [Power DC ▾]          W   │  [Voltage ▾]              V      │
│  ╭─────────────────────╮   │  ╭─────────────────────╮          │
│  │       ╱╲            │   │  │ ──────────── 253V   │          │
│  │     ╱    ╲   ╱╲    │   │  │    ╱╲               │          │
│  │   ╱        ╲╱   ╲  │   │  │  ╱    ╲             │          │
│  │ ╱                 ╲ │   │  │╱        ╲           │          │
│  ╰─────────────────────╯   │  ╰─────────────────────╯          │
│  ● Today  ◦ Yesterday     │  ● Today  ◦ Yesterday             │
├─────────────────────────────────────────────────────────────────┤
│  ⚠ 2 critical                                  12:30–13:15    │
└─────────────────────────────────────────────────────────────────┘

         │ klik [Status]
         ▼
┌─ Status (320×480) ──────────┐
│  [Statistics] [Status]      │
├────────────────────────────┤
│  StatusPopover              │
│  (unchanged content)        │
│                             │
│                    [Quit]   │
└────────────────────────────┘

         │ klik [↗]
         ▼
┌─ NSWindow (900×700) ───────┐
│  Full Statistics view       │
│  (as today, unchanged)      │
│  Popover closes             │
└────────────────────────────┘
```

## Key decisions

1. **Statistics is default** — no need to navigate to it
2. **Popover resizes dynamically** between tabs (820×520 ↔ 320×480) using NSPopover.contentSize animation
3. **Status tab kept** — evaluate usage over time, remove if unused
4. **Detach preserves state** — PeriodState and metric selections transfer to NSWindow
5. **Quit button** stays in Status tab (or right-click menu bar icon)
