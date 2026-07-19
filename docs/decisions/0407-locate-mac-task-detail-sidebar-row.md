# 0407: Locate Mac Task Detail Sidebar Row

## Status

Accepted

## Date

2026-07-19

## Refines

- [0252: Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md)
- [0285: Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md)

## Context

Mac task details can be opened from the task list, Planner, Timeline-style review, or fullscreen detail surfaces. After moving through those routes, users may need a fast way to find the selected task's row in the left task-list sidebar without reopening the detail or changing filters.

The sidebar already owns stable task-row identity and an explicit scroll-request mechanism. Rows can still be absent from the current task-list presentation because task-list mode, search, filters, or temporary form navigation hide them. Rows can also be present but visually hidden under collapsed sections or nested groups.

## Decision

On macOS, Command-Shift-L while a task detail is visible requests the left task-list sidebar row for that selected task.

If the selected task ID is present in the current task-list presentation, Home reveals the left sidebar column, expands the containing task-list section or nested group as needed, switches the sidebar back to task-list mode if needed, selects that task row, and scrolls it into view through the existing sidebar scroll request.

If the row is not present in the current task-list presentation, Home shows an informational toast instead of changing filters.

## Consequences

- The shortcut preserves the user's filters while opening only the collapse ancestors required to reveal the target row.
- Users get immediate feedback when the selected detail cannot be located in the current task-list sidebar.
- Future locate-style shortcuts should reuse the task-list presentation identity and scroll-request path instead of rebuilding sidebar membership.
