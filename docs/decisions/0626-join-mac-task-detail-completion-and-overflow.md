# 0626: Join Mac Task Detail Completion and Overflow

## Status

Accepted

## Date

2026-08-21

## Refines

- [0521 Group Secondary Mac Task Detail Actions](0521-group-secondary-mac-task-detail-actions.md)
- [0536 Match Mac Task Detail Overflow to Toolbar Chrome](0536-match-mac-task-detail-overflow-to-toolbar-chrome.md)

## Context

Full Mac Task Details correctly kept completion visible and moved secondary
lifecycle and destructive actions into the adjacent vertical-ellipsis menu.
Rendering those controls as two separate buttons nevertheless made their shared
task-lifecycle purpose less obvious, especially after Edit and Add a detail
became a clearly joined editing control.

Completion must remain the dominant everyday action. Visually joining the
overflow must not make destructive or maintenance actions appear equivalent to
Done, nor turn the control into one ambiguous hit target.

## Decision

Full Mac Task Details presents Done and the vertical-ellipsis menu as one joined
lifecycle control with a shared rounded outer shape and no inter-button gap:

- Done remains the left segment, retains its semantic green or orange completion
  tint, and continues to perform the primary completion or undo action directly.
- A narrow neutral right segment contains `⋮` and opens the existing native
  secondary-action menu. A divider separates it from Done, and only this segment
  receives the restrained accent treatment while its menu is open.
- Each segment owns its full visual hit surface and has its own accessibility
  label. Selecting either segment never triggers the other.
- The overflow menu contents, eligibility, destructive separation, and Delete
  confirmation remain unchanged.

The compact Mac companion pane continues to show a standalone completion button
because it intentionally omits the secondary-action overflow.

## Consequences

- The header communicates one lifecycle family while preserving a clear primary
  and secondary hierarchy.
- The control row has less disconnected button chrome without coloring the
  maintenance menu as a completion action.
- Existing task lifecycle behavior and safeguards do not change.
