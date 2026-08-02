# 0469: Store Task Descriptions Separately From Notes

Status: Accepted

Date: 2026-08-02

Refines: [0058 Use Progressive Task Forms](0058-use-progressive-task-forms.md), [0098 Support Markdown Text Editing Controls](0098-support-markdown-text-editing-controls.md), [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0277 Hide Notes and Away Behind Beta Toggles](0277-hide-notes-and-away-behind-beta-toggles.md), [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md), and [0462 Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)

## Context

Tasks need a stable place for the instructions or context required to perform them. Routina's existing task `notes` field cannot serve that role for every user because Notes is an experimental feature hidden by default, together with task notes and voice notes. Simply exposing that field as Description would contradict the Notes beta boundary and could silently change how existing note content is presented.

A second unstructured field without a clear distinction would also create ambiguity unless the product defines which surface is universally available and how existing Notes data behaves.

## Decision

Tasks store an optional plain-text `taskDescription` separately from experimental task notes. Description is stable task metadata and is available regardless of the Notes beta preference; existing task notes remain unchanged and continue to follow the Notes feature gate.

Add Task and Edit Task expose Description as its own progressive optional section on iOS and macOS. A populated Description remains visible in the form. Task Details renders the saved Description with its own label. Missing descriptions receive a field-specific Add More action: Mac edits the shared Description card inline, while iOS opens Edit Task with Description already revealed.

Description uses the shared Markdown-style plain-text editor and renderer. It is trimmed on save, and empty or whitespace-only input is stored as `nil`.

Description participates in task draft restoration, copying, Home and AI search, sharing, CloudKit direct-pull repair, backup/import, and cloud-usage estimates. Older tasks, creation drafts, shares, and backups decode with no description.

## Consequences

- Every task can carry durable instructions without enabling the broader Notes experiment.
- Existing task notes and voice notes retain their current feature-gated behavior and data.
- Description and Notes may coexist and are presented as distinct labeled text blocks in Task Details.
- New task data boundaries must preserve Description alongside the rest of the task's stable metadata.
