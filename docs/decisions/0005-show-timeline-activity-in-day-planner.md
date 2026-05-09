# 0005: Show Timeline Activity in the Day Planner

## Status

Accepted

## Date

2026-05-09

## Context

The day planner already surfaces completed tasks that happened on a date but were not placed as planner blocks. The timeline, however, is broader than completions: per [0003](0003-resolve-exact-time-missed-assumptions.md), done, missed, and canceled logs all belong to timeline activity.

Users need past timeline tasks to remain visible from the planner on the relevant date, so the planner can be used both for planning and for reviewing what actually happened.

## Decision

The day planner's date badges and focused task list show unplanned timeline activity, not only completed tasks. A task appears for a planner date when it has completed, missed, or canceled timeline activity on that date and it is not already represented by a planner block for that date.

Legacy task fields such as `lastDone` and one-off `canceledAt` remain fallbacks so older local data without full log history can still appear on the relevant planner date.

## Consequences

- Planner badges use timeline/activity language instead of "done" language.
- Missed and canceled timeline outcomes are available from the planner's relevant past date.
- Existing planner blocks still suppress duplicate timeline badges for the same task on the same date.
- Future planner filtering should preserve the distinction between placed plan blocks and unplanned historical activity.
