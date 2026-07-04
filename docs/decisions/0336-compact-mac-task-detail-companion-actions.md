# 0336: Compact Mac Task Detail Companion Actions

## Status

Accepted

## Date

2026-07-04

## Refines

- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)
- [0302: Minimize Fullscreen Mac Task Details to the Companion Pane](0302-minimize-fullscreen-mac-task-details-to-companion-pane.md)
- [0335: Move Mac Task Detail Actions Into Detail Content](0335-move-mac-task-detail-actions-into-detail-content.md)

## Context

Moving task detail actions into the task detail header clarified ownership and kept task controls out of the Home toolbar search interaction. In the right-side companion pane, the full action set still made the pane feel like it had two headers: a `Task Details` pane toolbar with expand/close controls, plus a task header action cluster with task-specific actions.

The companion pane needs only the task action that users perform most often and the two pane-level navigation controls. Secondary task actions belong in the fuller detail surface where there is enough room and context.

## Decision

The Mac task-detail companion pane does not render a separate `Task Details` toolbar strip. Its task header action cluster uses a compact companion style: the prominent completion action remains visible, and fullscreen/close icon buttons sit beside it.

The companion cluster omits routine Pause/Resume, one-off `Cancel todo`, deep-link sharing, Cloud sharing, and edit controls. Full Details keeps the broader action cluster, including secondary lifecycle actions, link/share/edit, minimize-back, and close.

## Consequences

- The right-side task detail pane has one visual header instead of a pane toolbar plus a task header.
- Companion-pane controls stay close to the selected task title while leaving advanced actions to Full Details.
- The expand and close hit targets remain full-size icon buttons in the same cluster as the completion action.
