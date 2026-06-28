# 0295: Present Mac Task Details Adjacent to Their Source

## Status

Superseded

## Date

2026-06-28

## Superseded by

- [0296: Present Mac Task Details as a Planner Inspector](../0296-present-mac-task-details-as-planner-inspector.md)

## Supersedes

- [0294: Present Mac Planner Task Details in a Companion Pane](0294-present-mac-planner-task-details-in-companion-pane.md)

## Refines

- [0004: Support Keyboard Navigation in the macOS Task List](../0004-macos-task-list-keyboard-navigation.md)
- [0037: Support Mac Home Back and Forward History](../0037-support-mac-home-back-forward-history.md)
- [0276: Open Mac Home to Planner](../0276-open-mac-home-to-planner.md)
- [0286: Present Planner Slot Actions in a Sidebar](../0286-present-planner-slot-actions-in-sidebar.md)

## Context

Mac Home task details can be opened from different spatial sources. When the user clicks a task in the left task list, replacing the whole workspace with full Details mode makes the result feel too large and detached from the clicked row. When the user opens a task from the Planner calendar, replacing Planner hides the calendar context they were inspecting.

Task detail therefore needs source-aware placement. It should appear immediately beside the source that selected the task, and fullscreen should remain an explicit expansion path rather than the default.

The Planner already owns an internal right sidebar for slot actions, day agendas, filters, and date picking. Task detail is broader than planner tooling, so it should not compete with that internal Planner sidebar.

## Decision

Selecting a task from the Mac task list opens a task-detail companion pane immediately to the right of the list, before the active workspace. Pointer and keyboard row selection use this route so the detail follows the selected row without replacing the whole workspace.

Opening a task from the Planner calendar keeps Planner visible and opens a task-detail companion pane on the right side of the Mac detail area. This includes planned timed blocks, all-day task blocks, automatic timeline task blocks, focus task blocks, and task rows opened from the Planner day-task agenda. The pane remains outside Planner's own right sidebar, which stays reserved for planner-specific secondary content.

Task-detail companion panes have close and fullscreen controls. Closing hides the pane without clearing the selected task. Fullscreen switches to Details mode for the selected task. Mac Home back/forward history records the companion pane placement only when a task is selected and the placement is compatible with the visible detail mode.

No task, planner-block, event, focus, Away, Sleep, or persistence model changes are introduced.

## Consequences

- Clicking a task row in the left list produces `list | task details | workspace` instead of a full workspace replacement.
- Calendar task inspection produces `Planner | task details`, preserving calendar context.
- Full task detail remains available through the explicit fullscreen control.
- Planner's internal right sidebar keeps its planner-specific role.
- Future Mac task-opening routes should choose the companion pane placement based on the source workspace.
