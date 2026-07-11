# 0367: Show Day Agenda Done Sections

Date: 2026-07-11

Status: Accepted

Refines: [0288 Open Planned Day Task List From Planner Headers](0288-open-planned-day-task-list-from-planner-headers.md), [0268 Show Assumed-Done Routines in Planner](0268-show-assumed-done-routines-in-planner.md)

## Context

The Planner day-header agenda originally opened a right sidebar focused on planned work for a selected date. Planner Calendar also shows completed automatic activity and synthetic assumed-done routine activity, so the day sidebar could omit work that was visible elsewhere on the same date.

Users need that sidebar to summarize the day without mixing recorded completion history with assumptions.

## Decision

The Planner day agenda groups task rows into `Planned tasks`, `Assumed done`, and `Dones`. The day-header agenda button shows one compact total count for the selected day's task work so the Calendar header stays scannable. The planned, assumed, and recorded breakdown remains available in the button help/accessibility text and in the sidebar section headers after the sidebar opens.

`Planned tasks` continues to use explicit Planner blocks, task-backed all-day items, and active date-only planned tasks. `Assumed done` uses synthetic assumed-done Planner activity. `Dones` uses recorded completed Planner activity, including completion-log rows and `lastDone` fallback activity.

Assumed and done rows follow the same presentation-only Calendar search and timeline-suggestion visibility as their corresponding Planner activity. They remain read-only agenda rows that can open task details; showing them in the agenda does not create completion logs, confirm assumed days, or change Planner storage.

## Consequences

- The day agenda can summarize planned, assumed, and completed task work for the selected date.
- The distinction between assumed completion and recorded completion remains visible and model-preserving.
- Planner filters and search continue to control which task-backed Calendar activity appears in both the grid and the day agenda.
