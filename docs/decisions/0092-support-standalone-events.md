# 0092. Support Standalone Events

## Status

Accepted

## Date

2026-05-28

## Context

Some user records are not tasks, routines, notes, or emotions. A person may want to record "sick", "travel day", "conference", or "family visit" because it explains the day and should appear on the calendar, but it should not gain completion, overdue, recurrence, or task-planning behavior.

Before this decision, the closest options were standalone notes, imported calendar-as-task records, or dated todos. Notes were good for text but did not occupy calendar time. Todos and imported calendar tasks showed on the planner but implied work to complete or manage.

## Decision

Routina has a standalone `RoutineEvent` SwiftData model for calendar-visible happenings. Events store title, optional notes, emoji, tags, all-day/timed date span, and created/updated timestamps. They are first-class personal records that appear in Timeline under an Events filter and in the Day Planner calendar as all-day or timed read-only event blocks.

Events are not tasks. They have no completion state, recurrence behavior, checklist, deadline pressure, reminder lifecycle, or planner block persistence. Tapping an event opens event detail/editing instead of task detail.

Events participate in durable data flows: backup/import, reset, duplicate cleanup, Settings tag management, iCloud usage estimates, and Stats summary counts.

## Consequences

- Use `RoutineEvent` when the user is recording that something happened or will happen and wants it visible on the calendar without task semantics.
- Continue using `RoutineNote` for freeform text that does not need a calendar span.
- Continue using `RoutineTask` for work the user intends to complete, miss, cancel, schedule, estimate, or repeat.
- Imported calendar-as-task metadata remains supported for old task-based calendar imports, but new app-native calendar-visible non-work records should prefer events.
