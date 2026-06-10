# 0205 Run Plan Focus From Planner

Status: Accepted

Date: 2026-06-10

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0106 Support Unassigned Watch Focus Sessions](0106-support-unassigned-watch-focus-sessions.md)

## Context

Users want to start a focus timer for the set of tasks they planned to do today, without choosing the exact task up front. They should only be able to start that timer when at least one task has been placed in `Plan to do today`, and they should be able to allocate the completed time to a task that is still in that plan later.

## Decision

Plan focus uses the existing unassigned `FocusSession` path instead of adding a new focus-session model or forcing task selection before work starts.

The Mac `Plan to do today` sidebar section exposes a compact stopwatch action when at least one non-daily task is planned for today. Starting from that section opens the Planner surface. The Planner shows the plan focus timer in a top control bar, with Start, Pause/Resume, Finish, and Abandon controls.

Finishing plan focus leaves the session unassigned and shows an allocation prompt in the same Planner top area. Allocation candidates are the tasks currently visible in `Plan to do today` at allocation time, including the nested daily routines group on Mac.

Active and newly finished plan focus renders as a Planner calendar block named `Plan Focus`. When the user allocates the session to a task, Routina saves a task-backed planner block for the completed focus duration so the calendar keeps the time evidence after attribution.

## Consequences

Plan focus stays lightweight and compatible with existing focus widgets, shielding, stats, and assignment behavior.

Because plan focus is stored as unassigned focus until allocation, attribution still uses the existing unassigned focus model. Planner rendering treats the unassigned session as temporary plan-focus evidence, then preserves it as task-backed planner time when allocation completes.
