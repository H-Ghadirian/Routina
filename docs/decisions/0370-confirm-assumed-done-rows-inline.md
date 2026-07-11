# 0370: Confirm Assumed-Done Rows Inline

Date: 2026-07-11

Status: Accepted

Refines: [0367 Show Day Agenda Done Sections](0367-show-day-agenda-done-sections.md), [0368 Hide Assumed-Done Calendar Layer by Default](0368-hide-assumed-done-calendar-layer-by-default.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

Planner day agendas and Calendar List columns surface synthetic `Assumed done` routine rows, but previous behavior kept those rows read-only. Users could see the assumed state but had to open task details or another surface to confirm whether the work really happened.

Assumed rows are most useful when they can be resolved quickly at the point of review.

## Decision

On Mac, hovering an assumed-done task row shows inline green check and red x buttons.

The green check records the assumed day as completed using the routine's assumed completion timestamp for that day. The red x records the assumed day as missed, keeping it separate from completed and canceled history. Both actions resolve the synthetic assumption so the row no longer appears as assumed for that day.

Home assumed-done rows use the current assumed occurrence day. Planner day agenda rows and Calendar List columns use the date represented by the row's day column or sidebar.

## Consequences

- Assumed-done review can be resolved without opening task details.
- Completion history remains factual: confirmed assumptions become completed logs, while rejected assumptions become missed logs.
- Planner `Assumed done` rows are no longer purely read-only, but opening task details remains available from the row itself.
