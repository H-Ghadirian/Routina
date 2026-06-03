# 0143: Present Mac Note Editing Inline

## Status

Accepted

## Date

2026-06-03

## Supersedes

- The modal default for Mac Home note editing implied by [0142](0142-edit-standalone-notes.md)

## Context

Mac Home already presents Add Note in the main detail area. Editing an existing note from the Mac Home detail area should feel like the same workflow, not a separate popup layered over the app.

## Decision

Mac Home owns note-edit presentation state. When a note detail in Mac Home asks to edit, Home replaces the main detail area with `RoutineNoteEditorView` configured for that existing note and its attachments.

The shared `RoutineNoteDetailView` accepts an optional edit callback. Hosts that provide the callback can present editing inline; hosts that do not provide it keep the reusable sheet fallback.

## Consequences

- Add Note and Edit Note use the same main-detail editor surface on Mac.
- Timeline-selected notes inside Mac Home can also edit in the main app area.
- Other note-detail hosts can keep modal editing until they adopt a host-owned inline route.
