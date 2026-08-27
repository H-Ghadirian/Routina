# 0681: Move Mac Focus Into the New Menu

## Status

Accepted

## Date

2026-08-27

## Supersedes

- [0278: Open Single Mac Add Action Directly](superseded/0278-open-single-mac-add-action-directly.md)
- [0333: Move Mac Focus Control to Planner Calendar Header](superseded/0333-move-mac-focus-control-to-planner-calendar-header.md)
- [0422: Keep Mac Focus Control in Planner Timeline](superseded/0422-keep-mac-focus-control-in-planner-timeline.md)
- [0614: Collapse the Planner Date Label When Focus Is Visible](superseded/0614-collapse-planner-date-label-when-focus-is-visible.md)

## Revises

- [0603: Start Mac Focus From One Recalling Sheet](0603-start-mac-focus-from-one-recalling-sheet.md)
- [0613: Measure Loaded Planner Header Against Visible Width](0613-measure-loaded-planner-header-against-visible-width.md)
- [0654: Progressively Reveal Mac Planner Header Choices](0654-progressively-reveal-mac-planner-header-choices.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0341: Consolidate the Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Revised By

- [0682: Present Mac New Menu as One Labeled Control](0682-present-mac-new-menu-as-one-labeled-control.md) gives the trigger one labeled surface and derives Focus availability from its eligible-task snapshot.

## Context

The Mac Planner header exposed Focus as a separate labeled control beside its
filter and date navigation. The global `+` control opened Add Task directly in
the standard production configuration because Task was its only available
creation action. This split made two common actions use different toolbar
locations, kept the Planner header wider, and hid their keyboard shortcuts until
the person already knew them.

The person requested one familiar menu behind `+`, matching the native
workspace menu pattern, with Add New Task and Focus together and each shortcut
visible.

## Decision

- The Mac top-toolbar `+` control always opens its native action menu. In the
  standard production configuration, the menu contains `Add New Task` followed
  by `Focus`.
- Enabled experimental creation actions retain their existing feature gates and
  order around those two standard actions.
- `Add New Task` keeps Control-Option-Command-T. `Focus` uses
  Control-Option-Command-F. Both use native menu keyboard shortcuts so macOS
  renders the shortcut beside the corresponding action.
- Choosing Focus opens the existing single sheet that recalls duration and tag
  context and lets the person start task-backed or tag-backed Focus. The menu
  action is unavailable when there is no startable work or another Focus or
  sprint timer is active.
- Active timers remain manageable through Routina's existing macOS timer/status
  menu. The Planner Calendar and Timeline headers no longer render a Focus
  start button, active plan-Focus control, or active non-plan Focus badge.
- Planner header fitting no longer reserves width or collapses `Go to date`
  because Focus became visible.

## Consequences

- Add Task and Focus are discoverable from the same global action surface in
  every workspace where the top toolbar is visible.
- The default `+` interaction gains one menu click for task creation, while its
  shortcut continues to provide a direct route.
- Planner navigation stays stable as tasks load or Focus state changes.
- Focus duration, attribution, storage, blocking, Planner evidence, history,
  and active-timer semantics do not change.
