# 0063: Tag Standalone Notes

## Status

Accepted

## Date

2026-05-26

## Context

Standalone notes already exist as first-class timeline evidence with text, image, voice, and file attachments. Tasks and goals use shared `RoutineTag` normalization and newline-backed tag storage, and tags drive timeline filtering, related-tag learning, backup/import, usage estimates, and Settings tag management.

Keeping notes outside that tag system would make note organization weaker than task and goal organization, and would make timeline tag filters incomplete for note-heavy capture.

## Decision

`RoutineNote` stores tags with the shared `RoutineTag` normalization and newline-backed `tagsStorage` model.

The note creation form includes tag entry, autocomplete from existing task, goal, and note tags, selected-tag removal, and existing-tag suggestions. Note detail shows saved tags, and Timeline note entries expose those tags so timeline tag filters include standalone notes.

Backup packages, import, iCloud usage estimates, Settings tag summaries, related-tag learning, and Settings rename/delete operations all include note tags.

## Consequences

- Tags behave consistently across tasks, goals, and standalone notes.
- Timeline tag filters can answer note-focused searches without creating fake tasks.
- Settings tag operations update note metadata and refresh note timestamps when a note tag changes.
- Future note editing should preserve the shared tag storage instead of introducing a note-only tagging system.
