# 0023: Edit Place Check-Ins from the Day Timeline

## Status

Accepted

## Date

2026-05-11

## Supersedes

- [0016: Show Place Check-Ins as a Day Timeline](0016-show-place-check-ins-as-day-timeline.md)

## Context

Place check-ins are meant to become reliable evidence for how time was spent across places. Automatic location capture and quick check-in flows can still create imperfect history: the user may choose the wrong activity, need to rename a raw current-location session, correct the time range, or remove an accidental check-in.

## Decision

The Places Day timeline is editable. Each check-in row exposes actions to edit or delete that session. Editing updates the session's stored place-name snapshot, activity, note, start time, and end time. Active check-ins may remain active or be ended from the editor, while already-ended sessions stay ended and only allow end-time correction. Deleting a session removes only that place check-in record.

## Consequences

- Users can correct their location history before using it for later analysis.
- Raw coordinate check-ins can be renamed without needing to create or mutate a saved place.
- The day timeline is no longer a read-only review surface; it is the primary correction surface for place-session history.
- Editing place-name snapshots does not rename saved places, preserving the difference between historical evidence and reusable place definitions.
