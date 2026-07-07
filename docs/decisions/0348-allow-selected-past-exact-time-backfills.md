# 0348 Allow Selected Past Exact Time Backfills

Status: Accepted

Date: 2026-07-07

Refines: [0328 Allow Past Day Checklist Runout Updates](0328-allow-past-day-checklist-runout-updates.md)

## Context

Task Details lets users review historical calendar days for a task. Exact-time routines with a time or time window can have multiple missed occurrences before the next future due date. The previous completion guard required earlier missed exact-time occurrences to be resolved before a later selected occurrence could be marked done.

That made a visible past occurrence selectable in the calendar while leaving the primary completion button disabled, even when the user was explicitly reviewing the date they wanted to backfill.

## Decision

Task Details can mark a real selected past exact-time routine occurrence done independently of older unresolved missed occurrences.

The selected day must still resolve to a scheduled occurrence, must not be in the future, and non-occurrence days remain blocked. Current-day completion still follows the normal availability and missed-occurrence rules unless the selected day resolves to a valid occurrence.

## Consequences

Users can backfill the specific occurrence they selected without first acknowledging every older missed occurrence. Older missed occurrences remain visible and unresolved until the user marks them missed, canceled, or done.
