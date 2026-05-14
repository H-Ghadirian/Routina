# 0048: Tag Goals

- **Status:** Accepted
- **Date:** 2026-05-14

## Context

Tasks already use tags for filtering, fast access, related-tag suggestions, colors, backup, and sync repair. Goals previously had hierarchy and task links, but no tag metadata of their own, so users could not group goals by lightweight labels without creating extra hierarchy.

## Decision

Goals store tags using the same `RoutineTag` normalization and newline-backed storage convention as tasks. Goal tags are edited in the inline goal editor, shown on goal rows/details, included in goal search, preserved by backup/import, and read from direct CloudKit pull payloads.

Settings tag management treats goal tags as part of the same tag space. Renaming or deleting a tag updates both tasks and goals, and tag summaries can report goal usage separately from routine and todo usage.

## Consequences

- Goal tags stay consistent with task tags and avoid a second parser or storage format.
- Settings tag actions become global across tagged Routina entities, so confirmation and success copy should mention goals when relevant.
- Task-centric stats and Home task filters can continue to count task usage only unless a future decision adds goal analytics.
