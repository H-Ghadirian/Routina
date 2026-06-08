# 0189: Auto-Save Creation Drafts

## Status

Accepted

## Date

2026-06-08

Refines [0173](0173-use-ios-new-tab-sheet.md), [0174](0174-do-not-restore-mac-add-task-composer.md), [0076](0076-select-saved-home-items-after-creation.md), and [0078](0078-present-mac-emotion-creation-inline.md) for creation continuity.

## Context

Routina has several lightweight creation surfaces: tasks, goals, notes, emotion logs, and events. These forms can be interrupted by app termination, tab changes, sidebar navigation, or platform presentation changes before the user explicitly saves.

Keeping only in-memory form state makes capture feel fragile, especially for longer task, goal, note, or emotion drafts. At the same time, draft state should not become a real user record, participate in backup/import, or undo the decision that Mac Add Task is a transient sidebar mode.

## Decision

Creation flows auto-save local drafts for new tasks, goals, notes, emotion logs, and events as the user edits them. Drafts are stored as local Codable snapshots in app defaults and are restored when the matching new-creation surface is opened again.

Drafts are only for new creation, not editing existing records. Explicit Cancel and successful Save clear the matching draft. Add Task continues to avoid restoring the Mac sidebar mode on relaunch; when the user opens Add Task again, the form hydrates from the saved draft. Linked-task creation ignores the general task draft so relationship-specific seeds remain intact.

## Consequences

- Interrupted capture can resume without prematurely inserting SwiftData records.
- Drafts are local app state, not synced user data and not backup/import entities.
- Save still routes to the saved record as the confirmation surface; cancel remains the user's explicit discard action.
- Future creation surfaces should either join this draft pattern or intentionally explain why interruption recovery is not appropriate.
