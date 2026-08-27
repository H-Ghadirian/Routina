# 0686: Combine Mac Workspace and Actions in One Menu

## Status

Accepted

## Date

2026-08-27

## Supersedes

- [0685: Merge Mac Workspace and Action Menus Into One Segmented Control](superseded/0685-merge-mac-workspace-and-action-menus-into-one-segmented-control.md)

## Revises

- [0681: Move Mac Focus Into the New Menu](0681-move-mac-focus-into-new-menu.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

The request to merge the workspace and `+` buttons meant combining their menu
contents, not drawing two independently clickable segments inside one outline.
Keeping two segments still required the person to choose a toolbar target before
seeing closely related global actions and destinations.

## Decision

- Mac Home exposes one workspace-labeled toolbar menu and no separate `+`
  trigger or `+` segment.
- `Add New Task` and `Focus` are the first two menu items. Any enabled
  feature-gated creation actions follow them in the same action group.
- A divider separates the action group from Planner, Backlog, Task Ladder, and
  the other enabled workspace destinations. A second divider continues to
  separate Settings from the workspace list.
- Add New Task and Focus retain their visible Control-Option-Command-T and
  Control-Option-Command-F shortcuts. Eligible-task availability and the visible
  `Another timer is running` explanation remain unchanged.
- The control's complete glass surface opens the combined menu. A running timer
  remains visible beside the Home sidebar toggle and the macOS timer/status menu
  remains an additional management route.

## Consequences

- One click reveals both the primary actions and the navigation destinations in
  a predictable top-to-bottom list.
- The selected workspace still labels the toolbar control, while the divider
  makes the boundary between actions and destinations explicit.
- Removing the `+` target reduces toolbar choice without removing an action,
  shortcut, timer explanation, or Focus management route.
