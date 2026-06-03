# 0055: Move iOS Home Place and Sleep Into Action Rail

## Status

Accepted

## Date

2026-05-25

Supersedes the bottom floating action placement from [0052](superseded/0052-use-compact-ios-home-actions.md) and updates the rail contents from [0054](superseded/0054-open-ios-home-top-actions-vertically.md).

## Context

After Home top actions moved into a vertical rail, the separate floating check-in and sleep buttons still occupied bottom Home space near the tab bar. Keeping them separate made Home feel split between two action systems and reduced room around the task list.

Check-in already opens the full map/check-in flow, and sleep already has a dedicated confirmation path for active focus timers. Both actions fit the Home action rail alongside Quick Add, Filters, and Add Task.

## Decision

iOS Home removes the bottom floating check-in and sleep controls.

The expanded top-right Home action rail includes Quick Add, Filters, Add Task, Check In, and Going to sleep. Check In opens the existing `PlaceCheckInMapSheet` with no preselected activity. Going to sleep starts the existing sleep flow, including the focus-timer warning when needed, and honors the existing Home sleep-action visibility preference using the prior stored default key for compatibility.

## Consequences

- Home uses one compact action surface instead of separate top and bottom affordances.
- The task list and bottom tab bar area have more breathing room.
- The previous Home sleep dock view is no longer part of the iOS Home presentation.
