# 0378: Open Mac Add Task From Toolbar Search With Command Return

## Status

Accepted

## Date

2026-07-12

## Refines

- [0074: Parse Mac Add Task Title](0074-parse-mac-add-task-title.md)
- [0189: Auto-Save Creation Drafts](0189-auto-save-creation-drafts.md)
- [0315: Merge Mac Quick Add Into Toolbar Search](0315-merge-mac-quick-add-into-toolbar-search.md)

## Context

Mac toolbar search already owns the fast search-or-create path. Pressing Return with a non-empty no-results query creates a task immediately through Quick Add, while explicit Add Task commands open the richer progressive form.

Sometimes the user starts typing in search and then decides they want the full form before saving. Forcing them to copy the query or retype it in Add Task makes the unified search entry point feel like a dead end for richer capture.

## Decision

When the Mac toolbar search field is focused, Command-Return opens the Mac Add Task form instead of creating immediately. The form is seeded with the trimmed search query in the Identity task-name field, toolbar search focus is dismissed, and the toolbar search text is cleared.

Plain Return keeps the existing Quick Add behavior and still creates only when the query is non-empty and has no visible task or timeline result.

The Command-Return seeded form intentionally bypasses the general saved Add Task draft for the initial state, like linked-task creation already does for relationship-specific seeds. Once the form is open, normal Add Task draft persistence resumes from the seeded state.

## Consequences

- Users can choose between fast save and rich form editing after typing the same search text.
- Existing no-results protection for plain Return remains unchanged.
- Explicit search seeds do not accidentally mix with an older autosaved task draft.
