# 0274: Present Resizable Planner Slot Draft

## Status

Superseded

## Superseded by

- [0286: Present Planner Slot Actions in a Sidebar](../0286-present-planner-slot-actions-in-sidebar.md)

## Date

2026-06-23

## Refines

- [0089: Prefer Native Apple Platform Patterns](../0089-prefer-native-apple-platform-patterns.md)
- [0269: Support Planner Slot Actions](../0269-support-planner-slot-actions.md)
- [0273: Log Sleep From Planner Away Slot Action](../0273-log-sleep-from-planner-away-slot-action.md)

## Context

Planner empty-slot actions originally opened a compact popover at the selected time. That made Task, Away, and Sleep capture possible from the grid, but the duration still felt detached from the calendar surface: users had to edit a duration control inside the popover and mentally translate that value back into a block of time.

Apple Calendar sets a clearer expectation for calendar-like grids: double-clicking empty time creates a visible draft block, and resizing that block changes the displayed start, end, and duration before the user commits the event. Routina should match that user-centered flow while preserving its distinct Task, Away, and Sleep persistence models.

## Decision

Double-clicking an empty timed Planner slot presents a temporary draft block in the calendar grid and anchors the slot action popover to that block. A single click can select the clicked time without starting creation. On macOS, the editor uses a native popover instead of an in-grid overlay so it can remain visible near window edges and, when appropriate, extend outside the app frame like Apple Calendar. The popover prefers the side of the draft for normal slots, but late-day slots can open above the draft so taller editor tabs remain visible. The native popover also measures its rendered content and shifts its anchor within the visible screen frame, keeping bottom-right/fullscreen presentations usable instead of requiring the user to move or leave fullscreen. The draft starts at the double-clicked 15-minute slot and uses the current planner duration as its initial size. Users can resize the draft from the top or bottom; the popover header and duration controls update from the same draft state.

The draft is presentation state only. Committing from the Task tab still creates a `DayPlanBlock`. Committing an Away option still logs a completed `AwaySession`. Committing Sleep still logs a completed `SleepSession`. No future scheduled Away, Sleep reservation, or generic calendar-event model is introduced by the draft.

## Consequences

- The Planner grid becomes the primary duration editor for empty-slot creation, reducing reliance on small stepper-style controls.
- The popover stays contextual by anchoring to the draft block rather than detaching from the selected time, without being clipped by the planner scroll viewport on macOS.
- Task, Away, and Sleep continue to use model-aware validation and conflict checks when the user commits the draft.
- Future slot-action UI should treat the visible draft as shared interaction state, not as persisted planner data.
