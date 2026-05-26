# 0072: Unify iOS Task Add and Quick Add

## Status

Accepted

## Date

2026-05-26

Updates [0058](0058-use-progressive-task-forms.md) and [0071](0071-move-ios-task-add-to-tab-bar.md).

## Context

iOS had two task creation paths: Add Task opened the full progressive task form, while Quick Add opened a separate natural-language capture sheet. That split made the fast path and the complete form feel like competing entry points even though they create the same task model.

The tab-bar Task action should stay fast enough for capture, but users still need an obvious way to review or edit richer task fields.

## Decision

iOS task creation opens a unified smart add flow first. The flow accepts natural-language task text, parses supported syntax such as recurrence, dates, time, tags, places, priority, and duration, and shows parsed fields as editable-preview chips before saving.

The smart flow can save directly through the shared Quick Add persistence path. A Details action seeds the existing full Add Task form from the parsed draft and then shows the progressive form for manual editing.

The iOS Home Quick Add action routes to the same unified task add flow instead of presenting a separate Quick Add-only sheet.

## Consequences

- iOS has one task creation entry model instead of separate Add Task and Quick Add flows.
- Quick capture remains one field and one save action.
- The full task form remains available for corrections and advanced fields without forcing it into the default capture path.
