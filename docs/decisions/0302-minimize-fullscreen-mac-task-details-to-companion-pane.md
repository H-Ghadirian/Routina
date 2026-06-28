# 0302: Minimize Fullscreen Mac Task Details to the Companion Pane

## Status

Accepted

## Date

2026-06-28

## Refines

- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0298: Close Fullscreen Mac Task Details to Planner](0298-close-fullscreen-mac-task-details-to-planner.md)

## Context

The Mac task-detail companion pane has an explicit fullscreen control. After using that control, full Details offered only the close action, which returned to Planner and cleared the pane. That made expansion feel one-way even though users often intend fullscreen as a temporary enlargement of the current inspector.

Direct fullscreen routes such as task-row double-clicks still need a simple close-to-Planner behavior because they did not originate from a companion pane.

## Decision

When full task details are opened by expanding a visible companion pane, Mac Home remembers the previous detail surface and companion-pane placement for that fullscreen session. The full task-detail toolbar shows a minimize/return control that restores that previous layout, such as Planner with the right-side task-detail companion pane.

The existing close control remains separate. Closing full Details still clears companion-pane state and returns the detail area to Planner, preserving the behavior from [0298](0298-close-fullscreen-mac-task-details-to-planner.md). Direct fullscreen openings that did not come from a companion pane do not show the minimize/return control.

No task, planner-block, event, focus, Away, Sleep, or persistence model changes are introduced.

## Consequences

- Expanding task details from the right Planner inspector is reversible without losing Planner context.
- Close and minimize remain distinct actions: close leaves full Details for Planner, while minimize restores the expanded-from pane.
- Double-click and deep-link fullscreen routes keep the simpler full Details close behavior.
