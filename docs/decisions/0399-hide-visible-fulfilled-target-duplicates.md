# 0399 Hide Visible Fulfilled Target Duplicates

Status: Accepted

Date: 2026-07-17

Refines: [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md), [0377 Fulfill Routines From Linked Task Completions](0377-fulfill-routines-from-linked-task-completions.md)

## Context

Linked task fulfillment lets a source task completion satisfy a target routine. In Planner day agendas and Calendar `List`, showing both the source task row and the target routine row can read as duplicate work for the same action when the source row is already visible in that day's task list.

## Decision

Planner day task lists keep fulfilled targets done for calendar, streak, review, Task Detail, and schedule-state purposes, but suppress a target's `Dones` row when that row is fulfillment-backed and at least one source task for the same fulfilled day is already visible in the same day task list.

The suppression is presentation-only. If the source task is hidden by the current Calendar search, task filters, activity hiding, or layer visibility, the fulfilled target may still appear so the completed routine state is not lost from review.

## Consequences

- Day agendas and Calendar `List` avoid double-listing one completed action as both the source and the fulfilled target.
- Fulfilled targets still count as done for their own detail, calendar, streak, and review state.
- Aggregate stats and global timeline activity remain governed by direct completed logs, as defined by linked task fulfillment.
