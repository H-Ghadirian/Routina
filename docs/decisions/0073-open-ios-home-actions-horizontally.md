# 0073: Open iOS Home Actions Horizontally

## Status

Accepted

## Date

2026-05-26

Supersedes [0054](superseded/0054-open-ios-home-top-actions-vertically.md) and updates [0055](0055-move-ios-home-place-and-sleep-into-action-rail.md).

## Context

The iOS Home top-right action menu had grown into a vertical icon rail to avoid squeezing the navigation title. After task creation moved to the iOS Task tab action and Quick Add was unified with Add Task, keeping Quick Add in the top-right Home action group duplicated the task creation entry point.

Without Quick Add, the remaining Home actions are compact enough to behave like the left task-list mode control. A horizontal reveal keeps both navigation bar controls visually consistent and avoids a floating panel that feels detached from the button that opened it.

## Decision

The iOS Home top-right action button expands horizontally inside the navigation bar. The ellipsis remains the rightmost toggle, and the action buttons reveal to its left.

The expanded action group includes Filters, Add Note, Check In, and Going to sleep when sleep is available. Quick Add is removed from this group because task creation is owned by the iOS Task tab action.

Selecting any action collapses the expanded toolbar group before opening the target flow.

## Consequences

- The left and right Home navigation bar controls now share the same inline expansion model.
- Task creation has one obvious iOS entry point through the Task tab action.
- The top-right group has less capacity for future actions; adding more actions should revisit whether they belong in the toolbar or a separate menu.
