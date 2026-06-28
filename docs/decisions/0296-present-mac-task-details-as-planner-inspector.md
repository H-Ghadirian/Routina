# 0296: Present Mac Task Details as a Planner Inspector

## Status

Accepted

## Date

2026-06-28

## Supersedes

- [0295: Present Mac Task Details Adjacent to Their Source](superseded/0295-present-mac-task-details-adjacent-to-source.md)

## Refines

- [0004: Support Keyboard Navigation in the macOS Task List](0004-macos-task-list-keyboard-navigation.md)
- [0037: Support Mac Home Back and Forward History](0037-support-mac-home-back-forward-history.md)
- [0276: Open Mac Home to Planner](0276-open-mac-home-to-planner.md)
- [0286: Present Planner Slot Actions in a Sidebar](0286-present-planner-slot-actions-in-sidebar.md)

## Context

Mac Home opens to Planner by default, so the left task list and the Planner calendar often work together as one planning surface. Placing task details between the task list and Planner preserves source adjacency, but it visually splits the task list from the active workspace and pushes the calendar away from the sidebar.

Planner should stay the center workspace when it is active. Task details complement Planner inspection, so they fit better as a right-side inspector than as an inserted middle column. Full Details mode remains available when the user explicitly expands the task details.

The Planner already owns an internal right sidebar for slot actions, day agendas, filters, and date picking. Task detail is broader than planner tooling, so it should remain outside that internal Planner sidebar.

## Decision

When Planner is the active Mac Home workspace, selecting a task from either the left task list or the Planner calendar keeps Planner visible and opens a task-detail companion pane on the right side of the Mac detail area. This produces `task list | Planner | task details` for list selection while Planner is active, and `Planner | task details` inside the detail area for calendar task inspection.

The right-side companion pane applies to planned timed blocks, all-day task blocks, automatic timeline task blocks, focus task blocks, task rows opened from the Planner day-task agenda, and task-list row or keyboard selection while Planner is active. The pane remains outside Planner's own right sidebar, which stays reserved for planner-specific secondary content.

The Mac detail area must not show the task-detail companion pane and a Planner internal right sidebar at the same time. Opening task details closes any Planner slot action, day task list, calendar filter, or date picker sidebar. Opening any of those Planner sidebars closes the task-detail companion pane first.

When Details is the active Mac Home workspace, task-list selection updates the regular Details surface. When other non-Planner workspaces are active and a task-list selection needs to preserve that workspace, a left-adjacent companion pane can still be used.

Task-detail companion panes have close and fullscreen controls. Closing hides the pane without clearing the selected task. Fullscreen switches to Details mode for the selected task. Mac Home back/forward history records companion pane placement only when a task is selected and the placement is compatible with the visible detail mode; stale left-adjacent Planner placements normalize to the right-side Planner inspector.

No task, planner-block, event, focus, Away, Sleep, or persistence model changes are introduced.

## Consequences

- Task-list selection while Planner is active keeps `task list | Planner | task details` instead of inserting details between the list and Planner.
- Calendar task inspection continues to preserve Planner context while giving access to task detail actions.
- The Mac detail area has one active right-side secondary surface at a time.
- Full task detail remains available through the explicit fullscreen control.
- Planner's internal right sidebar keeps its planner-specific role.
- Future Mac task-opening routes should choose the companion pane placement based on the active workspace, with Planner favoring a right-side inspector.
