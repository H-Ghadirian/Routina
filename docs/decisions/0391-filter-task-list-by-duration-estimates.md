# 0391 Filter Task List by Duration Estimates

Status: Accepted

Date: 2026-07-15

Refines: [0049 Filter Tasks and Done Items by Media](0049-filter-tasks-and-done-items-by-media.md)

## Context

Task duration estimates are optional metadata used for planning, focus, and time-spend review. Users need a fast way to find tasks that are missing this estimate so they can fill gaps without relying on an advanced text query or manually scanning rows.

Home task filters already use first-class shared filter models for comparable task metadata such as goals, media, created date, pressure, tags, and task state. Duration-estimate filtering should follow that same path so iOS, macOS, active rows, archived rows, summaries, and persistence stay aligned.

## Decision

Routina adds a shared `TaskEstimationFilter` with `All`, `Has Estimate`, and `No Estimate` options. Home task lists apply it to visible and archived task rows by checking whether `estimatedDurationMinutes` is present on the task display model.

The filter is exposed in the Home filter surfaces on iOS and macOS, appears in active-filter summaries and chips, and is saved with the same per-task-list-mode filter snapshots as other Home task filters.

## Consequences

- Users can directly review tasks that still need duration estimation.
- The filter remains additive to task type, status, tags, places, media, created date, and other Home filters.
- Future task-estimation metadata should extend this shared filter model rather than adding platform-specific scan behavior.
