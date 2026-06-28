# 0297: Open Mac Task Rows Fullscreen on Double Click

## Status

Accepted

## Date

2026-06-28

## Refines

- [0004: Support Keyboard Navigation in the macOS Task List](0004-macos-task-list-keyboard-navigation.md)
- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)

## Context

Mac Home task rows now use single-click selection to keep context visible. When Planner is active, a single click opens task details in the right-side companion inspector beside the calendar. Users still need a fast desktop gesture for opening the full task detail screen without first using the inspector's fullscreen control.

Double-click is a standard desktop affordance for opening the selected item in its primary detail surface. It should not change task, planner-block, focus, event, Away, Sleep, or persistence models.

## Decision

Single-clicking a Mac task-list row selects the task and follows the active-workspace presentation rule from [0296](0296-present-mac-task-details-as-planner-inspector.md). When Planner is active, this means opening the right-side task-detail companion pane and keeping Planner visible.

Double-clicking a Mac task-list row opens the selected task in the full Details surface. This is an explicit fullscreen route equivalent to choosing the companion pane's fullscreen control. It closes companion task-detail pane state and uses the regular Details mode for the selected task.

Keyboard row navigation continues to behave like selection, not fullscreen opening.

## Consequences

- One click inspects a task without disrupting Planner.
- Double click opens the full task-details screen immediately.
- Keyboard navigation remains a stable selection/inspection flow.
- Full Details remains available through both the explicit fullscreen control and the desktop double-click gesture.
