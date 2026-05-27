# 0087: Hide Automatic Planner Suggestions

## Status

Accepted

## Date

2026-05-27

## Context

Automatic timeline activity blocks in the planner are derived from task history. Users can confirm one into a normal planner block, but sometimes a derived suggestion is not useful in the planner and should be removed without deleting or rewriting the underlying timeline evidence.

## Decision

Automatic timeline activity blocks expose a "Hide from Planner" action in their context menu. Hiding stores a dismissal key for that derived activity in app settings and filters it out of automatic planner blocks, day badges, and the timeline-activity sidebar list.

Confirming still creates a persisted planner block and keeps using duplicate suppression. Hiding does not mutate the source `RoutineLog`, `lastDone`, or `canceledAt` timestamp.

## Consequences

- Users can dismiss individual planner suggestions without disabling the whole automatic timeline overlay.
- Timeline history remains intact because hiding is planner presentation state.
- Legacy fallback suggestions are keyed by task, day, and timestamp so a future completion or cancellation for the same task can still appear.
