# 0286: Present Planner Slot Actions in a Sidebar

## Status

Accepted

## Date

2026-06-27

## Supersedes

- [0274: Present Resizable Planner Slot Draft](superseded/0274-present-resizable-planner-slot-draft.md)

## Refines

- [0269: Support Planner Slot Actions](0269-support-planner-slot-actions.md)
- [0273: Log Sleep From Planner Away Slot Action](0273-log-sleep-from-planner-away-slot-action.md)

## Context

The resizable Planner draft block remains useful: it makes duration visible in the calendar grid before the user commits a Task, Away, or Sleep record. The native popover introduced for that editor tried to avoid in-grid clipping, but its anchoring, measured size, transient dismissal, and screen-edge behavior made empty-slot creation feel fragile.

Planner slot creation needs a steadier presentation surface. The calendar grid should keep owning time selection and draft resizing, while the action editor should live somewhere that is not dependent on popover arrow placement or screen-edge fitting.

## Decision

Double-clicking an empty timed Planner slot still presents a temporary resizable draft block in the calendar grid. The Task, Away, and Sleep action editor now appears in a right-side Planner sidebar instead of a native popover or in-grid floating panel. The sidebar is part of the Planner layout, has a stable width, scrolls independently, and closes by clearing the draft.

The draft remains presentation state only. Resizing the draft updates the sidebar's time range and duration controls from the same state. If the sidebar is open and the user selects another empty timed slot, the draft and sidebar move to that new date and start time rather than leaving stale editor content behind.

Committing from the Task tab still creates a `DayPlanBlock`. Committing an Away option still logs a completed `AwaySession`. Committing Sleep still logs a completed `SleepSession`. No future scheduled Away, Sleep reservation, or generic calendar-event model is introduced.

## Consequences

- Empty-slot creation no longer depends on popover sizing, arrow placement, or screen-edge anchoring.
- The visible draft block remains the grid-based duration editor.
- The Planner gives some horizontal space to the sidebar while the draft editor is open.
- Future slot-action UI should use the sidebar as the stable editor surface and keep model-specific persistence boundaries intact.
