# 0682: Present Mac New Menu as One Labeled Control

## Status

Accepted

## Date

2026-08-27

## Revises

- [0681: Move Mac Focus Into the New Menu](0681-move-mac-focus-into-new-menu.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

After Focus moved into the Mac `+` menu, the compact trigger rendered as a
loose plus followed by a native menu chevron. Those two marks did not read as
one control or align visually with the labeled workspace menu beside them.

The first implementation also decided whether Focus had startable work from
the current Home display count. That presentation count can be empty while the
eligible Focus-task snapshot still contains active work, so the global action
could become disabled for reasons unrelated to Focus availability.

## Decision

- The Mac action-menu trigger is one compact glass `New` control containing an
  accent plus, the `New` label, and an integrated chevron. The native menu
  indicator is hidden so a second detached chevron is not added.
- The complete visible surface owns the menu hit target and keeps the existing
  `New` accessibility label and descriptive help.
- Focus availability is derived from the eligible Focus-task snapshot, not
  visible or filtered Home rows. It remains unavailable when that snapshot is
  empty or a Focus or sprint timer is already active.
- Add New Task, Focus, their native menu order, and their visible keyboard
  shortcuts remain unchanged.

## Consequences

- The workspace and New menus read as a coherent toolbar pair.
- The trigger is more discoverable than an isolated plus while remaining
  compact and retaining the familiar creation symbol.
- Hiding or filtering every Home row cannot incorrectly disable Focus when an
  eligible task still exists.
- Genuine no-work and competing-timer states remain protected.
