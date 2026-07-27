# 0445 — Keep Satisfied Occurrences Out of Day Planning

Status: Accepted

Date: 2026-07-27

Refines: [0266 Show Calendar Routines in Plan Today](0266-show-calendar-routines-in-plan-today.md), [0438 Allow Early Completion of Untimed Scheduled Routines](0438-allow-early-completion-of-untimed-scheduled-routines.md), [0440 Treat Day Planning Sections as Additive](0440-treat-day-planning-sections-as-additive.md)

## Context

Fixed calendar routines automatically join Home `Today` when their configured
weekday or month day matches the current day. Early completion can satisfy that
scheduled occurrence on a prior day while retaining the actual completion date
in history.

The planning filter only checked whether the task was completed on the
projection day. A monthly rent routine completed on July 26 for its July 27
occurrence therefore returned to `Today` on July 27 even though its due date had
already advanced to August 27.

## Decision

Home `Today` and `Tomorrow` planning projections include only unresolved work
for the projected day. When a task's
`lastSatisfiedScheduledOccurrenceAt` identifies that day, the task does not
appear in that planning projection, regardless of whether the projection came
from fixed calendar recurrence or an explicit planned date.

The actual completion timestamp remains unchanged. Additive ordinary placement
also remains unchanged, so an active recurring task can still appear in its
Pinned, custom, or `Future` organization with its next due status. Undoing the
completion restores the scheduled-occurrence cursor and therefore restores
planning eligibility for that occurrence.

## Consequences

- Completing a July 27 occurrence on July 26 keeps the completion in July 26
  history and keeps the task out of July 27 `Today`.
- The recurring task remains available in its ordinary organization, showing
  the next due occurrence.
- A later scheduled occurrence becomes eligible for its own day projection.
- Planning surfaces must use scheduled-occurrence resolution identity in
  addition to actual completion-day state.
