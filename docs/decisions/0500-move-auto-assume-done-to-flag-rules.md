# 0500: Move Auto-Assume Done to Flag Rules

## Status

Accepted

## Date

2026-08-07

## Refines

- [0489: Expand Auto-Assume Done to Scheduled Repeats](0489-expand-auto-assume-done-to-scheduled-repeats.md)
- [0492: Allow Auto-Assume Done for One-Off Scheduled Blocks](0492-allow-auto-assume-done-for-one-off-scheduled-blocks.md)
- [0494: Allow Auto-Assume Done for Rolling After-Completion Routines](0494-allow-auto-assume-done-for-rolling-after-completion-routines.md)
- [0497: Use Flags for Task Behavior Rules](0497-use-flags-for-task-behavior-rules.md)

## Context

Auto-assume done is an application behavior, but it was selected by a
per-task scheduling toggle. That mixes a reusable behavior choice into each
task and makes it harder to express a personal category such as `tracking`.
Flags already provide the task-only, extensible home for application behavior.

Hiding an incompatible Flag from task forms would conceal a defined Flag and
make its absence confusing. The person should be able to see every Flag and
understand immediately why a particular Flag cannot be applied to the current
task.

## Decision

`Enable auto-assume done` is a typed Flag rule. Forms keep every defined Flag
tappable. When a person tries to add an auto-assume Flag to an incompatible
task, Routina leaves the Flag unassigned and shows the exact blocker plus the
supported task shapes.

The supported shapes are scheduled daily, weekly, monthly, or yearly routines
with at most one occurrence per day; eligible multi-day Standard `After done`
routines; and one-time Standard tasks with exactly one availability date and a
scheduled Time block. Steps, Standard optional checklists, cadence-free and
runout schedules, multiple daily occurrences, date windows, all-day timing,
exact-time timing, and availability windows remain ineligible.

An already assigned auto-assume Flag is never removed when schedule changes
make it ineligible. Its behavior is inactive while incompatible and becomes
active again automatically if the task becomes eligible. The existing persisted
boolean remains a materialized compatibility value for the assumption engine
and for one-time migration.

Settings offer a one-time migration that adds a chosen auto-assume Flag to all
tasks that already have legacy auto-assume completion enabled. Adding or
removing the rule also reconciles matching stored tasks immediately.

## Consequences

- Auto-assume behavior can be applied consistently by assigning one Flag.
- The obsolete form toggle is removed; Calendar visibility remains a
  task-level preference available while an eligible auto-assume Flag is active.
- Existing legacy tasks continue to work until migration, protecting the sole
  user's data while the new Flag-based workflow is adopted.
- Future behavior rules follow the same visible-selection and contextual
  validation pattern instead of disappearing from a task form.
