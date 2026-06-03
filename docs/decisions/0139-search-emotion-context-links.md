# 0139: Search Emotion Context Links

## Status

Accepted

## Date

2026-06-03

## Context

Emotion logs can link to notes, goals, tasks, places, and sleep sessions. The editor originally used compact menus for those links. Menus worked when there were only a few records, but task and note histories can grow large enough that finding the right context becomes slow and visually overwhelming.

## Decision

Emotion context link controls keep the compact link tiles in the editor, but selecting a tile opens a bounded searchable picker. The picker shows the item count, supports case-insensitive and diacritic-insensitive search, lets users clear the existing link, and closes after selecting a result.

## Consequences

- Linking emotions to tasks, notes, goals, places, or sleep remains optional and compact.
- Large task or note histories are searchable instead of presented as full-height menus.
- The underlying `EmotionLog` link fields and detail-view deep-link behavior stay unchanged.
