# 0685: Merge Mac Workspace and Action Menus Into One Segmented Control

## Status

Superseded by [0686: Combine Mac Workspace and Actions in One Menu](../0686-combine-mac-workspace-and-actions-in-one-menu.md)

## Date

2026-08-27

## Supersedes

- [0684: Restore Compact Mac Menu Triggers and Surface the Active Timer](0684-restore-compact-mac-menu-triggers-and-surface-the-active-timer.md)

## Revises

- [0681: Move Mac Focus Into the New Menu](../0681-move-mac-focus-into-new-menu.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](../0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](../0264-match-button-hit-areas-to-visual-surfaces.md)
- [0341: Consolidate Mac Home Toolbar Row](../0341-consolidate-mac-home-toolbar-row.md)

## Context

Restoring the compact Planner selector and rounded `+` recovered their familiar
contents, but keeping two adjacent glass outlines still made one command cluster
read as two unrelated toolbar buttons. The person asked to merge them after
reviewing that restored presentation.

The two segments still own different menus, so the visual merge must not turn
the pair into one ambiguous action or reduce either hit target.

## Decision

- The workspace selector and action menu share one 32-point-high rounded glass
  surface. A thin separator divides the two independently interactive segments.
- The left segment keeps the selected workspace icon, title, and disclosure and
  opens the workspace menu. The right segment keeps the accent `+` and opens the
  Add New Task and Focus menu.
- Each segment fills its complete visible portion with a rectangular content
  shape. The shared outer surface supplies the rounded silhouette; neither
  segment draws a second glass outline.
- Add New Task, Focus, their visible shortcuts, eligible-task availability, and
  the `Another timer is running` explanation remain unchanged.
- A running timer remains visible beside the Home sidebar toggle and opens its
  existing controls. The macOS timer/status menu remains an additional route,
  and Planner headers do not regain Focus controls.

## Consequences

- Workspace switching and creation read as one compact toolbar command group
  without combining their behavior.
- The separator and distinct icons preserve the boundary between the two menus.
- The right `+` segment retains the same direct Focus explanation and keyboard
  shortcut discovery as before the visual merge.
