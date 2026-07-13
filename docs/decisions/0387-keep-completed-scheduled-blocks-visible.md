# 0387: Keep Completed Scheduled Blocks Visible

Date: 2026-07-13

Status: Accepted

Refines: [0372 Hide Completed Tasks From Calendar Schedule](0372-hide-completed-tasks-from-calendar-schedule.md), [0375 Split Time Blocks From Available Windows](0375-split-time-blocks-from-available-windows.md)

## Context

Decision 0372 kept completion-derived timeline activity out of the editable Planner Calendar `Schedule` so marking a task done would not create new automatic blocks. That rule also hid task blocks that were already supposed to be on the calendar, such as explicit Planner placements, exact `At time` task schedules, all-day task placements, and fixed `Time block` ranges.

Users expect those scheduled commitments to remain visible after marking the occurrence done. A completed meeting-like `Time block` is still a real calendar block; completion should change review/status presentation, not erase the scheduled span.

## Decision

Completion and fulfillment outcomes no longer hide task-backed Schedule blocks that otherwise qualify for Calendar visibility. Persisted Planner placements, all-day task placements, exact `At time` / exact date-time task metadata, and fixed `Time block` ranges remain visible after the occurrence is marked done.

Completion-derived automatic timeline activity still does not create or render timed Schedule blocks, Needs Time blocks, or all-day Schedule blocks. Recorded completions and synthetic assumed-done rows remain available in the day task sidebar and Calendar `List` columns under `Dones` and `Assumed done`.

Missed, canceled, and synthetic assumed-done outcomes continue to suppress task-backed Schedule blocks for that day unless a later decision changes those states explicitly.

## Consequences

- Fixed calendar commitments stay visible as calendar commitments after completion.
- Calendar `Schedule` and Calendar `List` can both represent the same completed scheduled occurrence: Schedule shows the block, while List/day agenda shows its done state.
- The app still avoids creating new Schedule blocks from ordinary completion history.
