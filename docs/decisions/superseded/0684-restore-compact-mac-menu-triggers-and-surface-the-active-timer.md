# 0684: Restore Compact Mac Menu Triggers and Surface the Active Timer

## Status

Superseded by [0685: Merge Mac Workspace and Action Menus Into One Segmented Control](0685-merge-mac-workspace-and-action-menus-into-one-segmented-control.md), which was superseded by [0686: Combine Mac Workspace and Actions in One Menu](../0686-combine-mac-workspace-and-actions-in-one-menu.md)

## Date

2026-08-27

## Supersedes

- [0682: Present Mac New Menu as One Labeled Control](0682-present-mac-new-menu-as-one-labeled-control.md)

## Revises

- [0681: Move Mac Focus Into the New Menu](../0681-move-mac-focus-into-new-menu.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](../0264-match-button-hit-areas-to-visual-surfaces.md)
- [0341: Consolidate Mac Home Toolbar Row](../0341-consolidate-mac-home-toolbar-row.md)

## Context

Labeling the compact Mac action trigger as `New` and hiding the native menu
indicators changed both toolbar controls after the user had already accepted
their earlier workspace-menu and rounded-plus silhouettes. The new pair read as
loose text instead of familiar controls.

When another Focus or sprint timer was active, the Focus menu row was correctly
disabled but explained the reason only through hover help and a separate status
menu. The person could neither see why from the open `+` menu nor see the live
timer beside the Home navigation control where they expected it.

## Decision

- The labeled workspace selector keeps its previous compact menu presentation,
  and the action-menu trigger returns to the separate 32-point rounded `+`
  surface. The `+` does not add a `New` text label or hide the menu's ordinary
  affordance.
- The `+` menu continues to own Add New Task and Focus, including their visible
  Control-Option-Command-T and Control-Option-Command-F shortcuts. Focus
  availability continues to come from the eligible Focus-task snapshot rather
  than currently visible Home rows.
- While a Focus or sprint timer is active, Focus remains disabled and the menu
  shows `Another timer is running` immediately after it. A no-startable-task
  state remains disabled without claiming that a competing timer exists.
- Home shows the existing interactive live timer badge immediately to the right
  of the sidebar toggle. The compact badge shows the stable-width running time
  and opens the existing Pause/Resume, Finish, Abandon, and destination actions
  supported by that timer.
- The macOS timer/status menu remains an additional management route. Planner
  headers do not regain a separate Focus start or active-timer control.

## Consequences

- The two action controls regain the compact shapes the person recognized
  before Focus moved into the global menu.
- Opening `+` explains a competing timer at the same point where Focus becomes
  unavailable.
- A running timer remains visible and actionable from Home without making the
  Planner header resize or change state.
