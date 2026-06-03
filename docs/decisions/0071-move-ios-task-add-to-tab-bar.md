# 0071: Move iOS Task Add to the Tab Bar

## Status

Accepted

## Date

2026-05-26

Updates [0033](0033-use-app-owned-ios-more-tab.md), [0054](superseded/0054-open-ios-home-top-actions-vertically.md), and [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md).

## Context

Compact iOS Home had several creation and action controls in the expanded top-right action rail. As notes, check-ins, sleep, filters, and quick add accumulated there, the plain plus button for creating a task competed with other Home-only actions.

The bottom tab bar is already the primary compact iOS navigation surface. Moving task creation there keeps the plus action visible from any tab and lets the Home action rail focus on Home utilities.

Goals also occupied a primary bottom tab slot. With task creation becoming a tab-bar action, Goals should move into the existing app-owned More flow to keep the compact tab bar clean.

## Decision

iOS shows a Task tab-bar action with a plus icon between Search and Timeline. Selecting it switches to Home and opens the existing task creation flow, but Add Task is not stored as a real app tab or restored temporary destination.

Compact iOS removes Goals from the primary tab bar and lists Goals in the app-owned More section alongside Stats and Settings. Goal deep links continue to select the Goals destination so the More tab can restore the appropriate secondary screen.

The Home top action rail removes Add Task and keeps Quick Add, Filters, Add Note, Check In, and Going to sleep.

Regular-width iOS keeps Goals as a direct tab, while compact/regular layout selection continues to follow SwiftUI size classes.

## Consequences

- The compact iOS bottom bar stays at five visible items: Home, Search, Task, Timeline, and More.
- Task creation is available from every iOS tab without overloading the Home action rail.
- Goals remain reachable and deep-linkable, but no longer consume primary compact tab-bar space.
