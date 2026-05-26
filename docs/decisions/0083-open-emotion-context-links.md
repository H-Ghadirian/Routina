# 0083: Open Emotion Context Links

## Status

Accepted

## Date

2026-05-27

## Context

Emotion logs can link to notes, goals, tasks, places, and sleep sessions. The detail view showed those links as static labels, which made linked notes, goals, and tasks feel broken when users expected to open the related record.

## Decision

Emotion detail rows for linked notes, goals, and tasks open the app's existing deep-link routing for that entity. This keeps linked context navigation aligned with the app-wide task, goal, and note opening behavior.

Place and sleep rows remain read-only until those entity types have dedicated deep-link destinations.

## Consequences

- Linked notes, goals, and tasks from an emotion log are actionable.
- Emotion detail does not duplicate task, goal, or note presentation logic.
- Future place and sleep detail routing can extend the same pattern once stable destinations exist.
