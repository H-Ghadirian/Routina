# 0600: Edit Recorded Tag Focus From Mac Planner

## Status

Accepted

## Date

2026-08-17

## Refines

- [0267: Support Mac Toolbar Tag Focus](0267-support-mac-toolbar-tag-focus.md)
- [0286: Present Planner Slot Actions in a Sidebar](0286-present-planner-slot-actions-in-sidebar.md)
- [0296: Present Mac Task Details as a Planner Inspector](0296-present-mac-task-details-as-planner-inspector.md)

## Context

Tag Focus creates calendar evidence without owning a task. A completed `#Tag`
block therefore has no useful task-detail destination when the person discovers
that its recorded start or duration is wrong while reviewing Calendar
`Schedule`.

The correction should stay beside the calendar and update the owning Focus
history rather than changing only the Planner projection. Task-linked Focus
blocks already have a distinct task-detail route that should remain unchanged.

## Decision

On macOS Calendar `Schedule`, double-clicking a completed tag Focus block opens
a Planner-owned right sidebar for that recorded Focus session. The sidebar
shows the tag, start, duration, and derived end, and offers direct duration
adjustments and common presets.

Saving changes the owning `FocusSession` start and duration and rebuilds its
persisted Planner evidence from the corrected values. A corrected session that
previously contained pause/resume segments becomes one continuous recorded
interval, matching the existing completed-Focus editor contract.

Active tag Focus remains controlled by the live Focus controls and does not
open this historical editor. Task Focus blocks retain their existing task-detail
behavior, and unassigned Plan Focus and board Focus are unchanged.

The tag Focus sidebar participates in Planner's existing one-secondary-surface
rule with slot actions, day tasks, filters, date selection, and the external
task-detail companion pane.

## Consequences

- A person can correct recorded tag Focus without leaving the Calendar context.
- Focus history, Planner evidence, Timeline, and Stats consume the same corrected
  start and duration instead of allowing the calendar block to diverge.
- Correcting a paused historical session intentionally replaces its segmented
  evidence with one continuous interval.
- Task-linked and active Focus navigation remains unchanged.
