# 0294: Present Mac Planner Task Details in a Companion Pane

## Status

Superseded

## Date

2026-06-28

## Superseded by

- [0295: Present Mac Task Details Adjacent to Their Source](0295-present-mac-task-details-adjacent-to-source.md)

## Refines

- [0004: Support Keyboard Navigation in the macOS Task List](../0004-macos-task-list-keyboard-navigation.md)
- [0037: Support Mac Home Back and Forward History](../0037-support-mac-home-back-forward-history.md)
- [0276: Open Mac Home to Planner](../0276-open-mac-home-to-planner.md)
- [0286: Present Planner Slot Actions in a Sidebar](../0286-present-planner-slot-actions-in-sidebar.md)

## Context

Mac Home has two common ways to select a task: from the left task list and from the Planner calendar. Treating both sources as a hard switch to the Details surface makes Planner task inspection feel disruptive because the calendar disappears. Keeping task-list selection on Planner also weakens the desktop list expectation that the detail follows the selected row.

The Planner already owns an internal right sidebar for planner-specific secondary content such as slot actions, day agendas, filters, and date picking. Task detail is broader than planner tooling, so it needs a companion surface that does not compete with those Planner sidebar modes.

## Decision

Selecting a task from the Mac task list opens the full task detail surface in Details mode beside the list. Pointer and keyboard selection use this route so row navigation keeps the detail pane aligned with the selected task.

Opening a task from the Planner calendar keeps Planner visible and opens a task-detail companion pane on the right side of the Mac detail area. This includes planned timed blocks, all-day task blocks, automatic timeline task blocks, focus task blocks, and task rows opened from the Planner day-task agenda. The companion pane is outside the Planner's own right sidebar, which remains reserved for slot actions, day agendas, filters, and date picking.

The companion pane has close and fullscreen controls. Closing hides the pane without clearing the selected task. Fullscreen switches to Details mode for the selected task. Mac Home back/forward history records the companion pane only when Planner has a selected task; non-task Planner routes such as Sleep or unassigned focus keep the task pane closed.

No task, planner-block, event, focus, Away, Sleep, or persistence model changes are introduced.

## Consequences

- Task-list selection behaves like a desktop source list with an adjacent full detail surface.
- Calendar task inspection preserves Planner context while still giving access to task detail actions.
- Planner's internal right sidebar keeps its planner-specific role.
- Future Mac task-opening routes should choose the presentation based on the source workspace rather than always switching to Details.
