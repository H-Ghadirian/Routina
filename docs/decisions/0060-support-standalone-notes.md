# 0060: Support Standalone Notes

## Status

Accepted

## Date

2026-05-26

## Supersedes

- [0059: Use a Mac Home Sidebar Add Menu](superseded/0059-use-mac-home-sidebar-add-menu.md)
- The Timeline-only media-filter exclusions in [0049](0049-filter-tasks-and-done-items-by-media.md) and [0053](0053-record-task-voice-notes.md)

## Context

Not every captured item is a task or a goal. Users need a lightweight way to store free-standing notes, including document context, an image, or a spoken thought, and then find that evidence later in the same chronological review surface as done work, places, and sleep.

Existing media support was split across task images, task files, task voice notes, and place check-in images. Notes need their own ownership boundary so they can exist without a routine task, while still participating in backup, import, reset, duplicate cleanup, usage estimates, and timeline filtering.

## Decision

Routina models standalone notes as `RoutineNote` records with optional title, body, one compressed image, and one M4A voice note stored via SwiftData external storage. Arbitrary note files are separate `RoutineNoteAttachment` records linked by note ID.

The primary add controls can create notes: the iOS Home action rail adds an Add Note action, and the macOS Home sidebar `+` menu now contains Note, Goal, and Task. Goal creation still switches to Goals and opens the inline editor; task creation still opens the existing add-task form.

Timeline includes notes as first-class entries under a Notes type filter. Timeline media filtering applies to all media-bearing timeline entries: task image/file/voice, note image/file/voice, and place check-in images. Home task-list media filtering remains task image/file focused because it filters tasks, not timeline evidence.

Backup packages export note images, note voice notes, and note files as attachment files referenced from the manifest. Import restores notes and attachments, and reset/duplicate-cleanup flows treat notes as owned app data.

## Consequences

- Users can capture information that should not become a to-do or routine.
- Notes stay reviewable by date without adding planner or task-state semantics.
- Timeline media filters now answer evidence-oriented questions across tasks, notes, and places, while Home task filters remain scoped to task rows.
- Future note editing, deletion, and file-opening affordances should preserve the standalone note model instead of reusing task attachments.
