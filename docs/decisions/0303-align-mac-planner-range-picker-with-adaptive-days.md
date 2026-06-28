# 0303: Align Mac Planner Range Picker with Adaptive Days

## Status

Accepted

## Date

2026-06-28

## Supersedes

- [0301: Adapt Mac Planner Week Visible Days](superseded/0301-adapt-mac-planner-week-visible-days.md)

## Refines

- [0191: Support One-Day Planner View](0191-support-one-day-planner-view.md)
- [0292: Unify Planner Header Date Control](0292-unify-planner-header-date-control.md)
- [0299: Constrain Mac Home Window Size for Planner Inspector](0299-constrain-mac-home-window-size.md)

## Context

Mac Planner Week mode adapted to seven, three, or one visible day as the calendar column narrowed, but the header range picker still selected `Week`. That made the visible calendar and the selected control disagree, especially when the UI showed only one day.

The app still needs width-adaptive planner ranges so the Mac Home sidebar, Planner, and task-detail companion pane can fit together without unreadable columns. It also needs to respect an explicit user choice to work in one-day mode when the window later grows.

## Decision

The Mac Planner range picker offers three explicit options: `Day`, `3 Days`, and `Week`.

Planner keeps a user-preferred range and derives the effective displayed range from available calendar width. A preferred `Week` range displays `Week` on wide calendars, `3 Days` on medium calendars, and `Day` on narrow calendars. The selected segment always matches the effective rendered range.

If the user explicitly selects `Day`, that preference stays pinned as the window grows from a narrow layout to fullscreen; the picker and view remain on `Day`. Explicit `3 Days` and `Week` preferences may temporarily constrain downward when the window is too narrow and restore when width allows.

The visible range title, Today visibility, loaded planner data, and previous/next navigation follow the effective range. `Day` keeps day-specific hour spacing controls, while `3 Days` and `Week` use the standard compact planner hour height. Planner storage remains unchanged.

## Consequences

- The segmented picker no longer claims `Week` while the calendar is rendering three days or one day.
- Users can intentionally choose a focused one-day planner and keep it while resizing wider.
- `3 Days` becomes a first-class planner range without introducing new planner persistence.
