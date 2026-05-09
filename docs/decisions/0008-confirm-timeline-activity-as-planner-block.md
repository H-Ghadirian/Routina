# 0008 Confirm Timeline Activity as Planner Blocks

- Status: Accepted
- Date: 2026-05-09

## Context

Automatic timeline activity in the planner is useful for reviewing what happened, but users sometimes want to accept one of those automatically placed routines into the plan so it behaves like a normal user-placed planner block.

## Decision

Automatic timeline activity blocks can be confirmed from their planner context menu. Confirming creates a persisted `DayPlanBlockRecord` using the automatic block's task, date, start time, duration, title, and emoji snapshot. The source timeline log or legacy activity timestamp is not changed by confirmation.

Once confirmed, the task is represented by a normal planner block on that day, so the automatic timeline overlay for the same task and day is suppressed by the existing duplicate-prevention behavior.

## Consequences

- Confirmed activities become solid, selectable planner blocks and can use the normal planner block interactions.
- Confirmation records user intent without rewriting historical timeline data.
- Re-confirming the same visible activity does not create duplicate planner blocks for the same task on the same day.
