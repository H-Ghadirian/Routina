# 0012: Model Sleep as an App-Level Session Mode

## Status

Accepted

## Date

2026-05-10

## Context

Sleep check-in and wake-up should be faster than a normal routine flow. Opening a routine row and marking it done adds friction at exactly the moment the user wants to stop using the app.

Sleep may be a nap, shift sleep, or overnight sleep. It spans a duration and can cross midnight, so a single routine completion timestamp does not capture the behavior well enough for future planner and stats work.

## Decision

Routina records sleep as dedicated `SleepSession` data with a start time, end time, and target duration. Starting sleep is exposed through a home-level sleep dock, Siri/App Shortcuts, a shake-to-start confirmation on iOS while the app is open, and a visible toolbar/menu command on macOS.

Users can disable the home sleep dock, the Home tab long-press menu entry, and the iOS shake shortcut from Settings. These entry points remain enabled by default so the primary sleep flow is discoverable after the feature ships.

When a sleep session is active, Routina presents a full-screen sleep mode gate above the app. The gate uses time-neutral sleep wording and shows start time, estimated wake time, elapsed sleep duration, and a primary "I'm awake" action. The rest of the app is disabled until the session is ended or the user undoes the sleep mode start.

Sleep mode and focus timers must not overlap. If a focus timer is active, visible sleep entry points warn the user that starting sleep will stop the timer before proceeding. Starting sleep then stops active task and sprint focus timers at the sleep start time, and focus-start entry points reject new timers while a sleep session is active.

Completed and active sleep sessions appear in Timeline as first-class sleep records rather than routine completions. In the day planner, sleep sessions render as protected sleep blocks split across calendar days when necessary. The planner rejects dragging, dropping, resizing, confirming timeline activity, and exact-time auto-placement when the target interval overlaps a sleep block.

## Consequences

- Sleep no longer needs to be represented as a routine row or a routine completion action.
- Active sleep is an app-wide mode rather than a task detail state.
- Focus time cannot continue running under the sleep gate, so sleep history and focus stats stay separate.
- Sleep data can be rendered in planner, timeline, widgets, and stats without overloading `RoutineLog`.
- Planner sleep blocks are derived from `SleepSession` records and are not saved as normal editable task blocks.
- Backup, import, and local reset flows must include `SleepSession` records so sleep history remains part of user data.
