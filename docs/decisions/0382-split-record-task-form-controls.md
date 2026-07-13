# 0382 Split Record Task Form Controls

Status: Accepted

Date: 2026-07-13

Refines: [0380 Add Record Task Type](0380-add-record-task-type.md), [0381 Make Mac Task Detail Heatmap Optional](0381-make-mac-task-detail-heatmap-optional.md)

Refined by: [0383 Use Tracking as Record Label](0383-use-tracking-as-record-label.md) for user-facing task-kind naming, and [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md) for routine-like Tracking repeat controls.

## Context

The first Record task type kept records intentionally minimal: no due dates, no repeat configuration, no routine duration, no steps, and no checklist data. That avoided accidental scheduling pressure, but it also made records less useful for time-spend analysis, because records often need the same descriptive structure as routines while remaining unscheduled.

The task form also presented `Routine`, `Todo`, and `Record` as one flat control. Records are conceptually a different entry kind from tasks, while `Todo` and `Routine` are the two task subtypes.

## Decision

Task forms split the type controls into a primary `Record` / `Task` segment. When `Task` is selected, a nested `Todo` / `Routine` segment chooses the task subtype.

Records keep routine-like form metadata for analysis: completion mode (`Standard` or `Checklist`), duration, all-day/time availability, steps for standard records, checklist items for checklist records, estimated time, actual time, focus metadata, notes, links, tags, goals, places, media, attachments, relationships, events, comments, history, and heatmap support. Record checklist item intervals normalize to one day so they remain checklist structure, not repeat cadence.

Records still do not expose or persist due dates, reminders, date availability, planned dates, `Due Style`, `Repeat type`, or `Repeat` controls. Their recurrence storage remains a neutral one-day interval for compatibility, but may carry exact-time or time-window metadata without making the record due, overdue, planned, or repeating.

## Consequences

Users can log analysis records with enough structure to explain what happened and where time went, without creating fake todos or recurring obligations.

Future Record work should treat records as unscheduled entries that may still carry routine-style descriptive metadata. New due, reminder, planning, or repeat behavior must explicitly opt records in.
