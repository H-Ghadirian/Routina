# 0624: Hide Empty Linked Tasks by Default

## Status

Accepted

## Date

2026-08-21

## Refines

- [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md)
- [0366 Keep Mac Task Detail Add More Inline](0366-keep-mac-task-detail-add-more-inline.md)
- [0512 Present Mac Relationship Suggestions in the Link Task Sheet](0512-present-mac-relationship-suggestions-in-link-task-sheet.md)

## Refined By

- [0625 Group Task Detail Add Detail With Edit](0625-group-task-detail-add-detail-with-edit.md)
- [0630 Compose Task Relationships With Grouped Sentence Fragments](0630-compose-task-relationships-with-grouped-sentence-fragments.md)

## Context

An empty Linked Tasks card adds a large block of relationship controls to every
Task Detail, even when the task has no relationship to review. iOS already uses
progressive disclosure for this state, while macOS retained an unconditional
section after relationship suggestions moved into the Link Task sheet.

## Decision

iOS and macOS Task Details hide the Linked Tasks section when the task has no
resolved relationships. The optional-detail catalog keeps `Linked Task` as the
deliberate entry point for starting a relationship. Decision 0625 later moves
that catalog from a scrolling Add More card into the header's grouped Edit / Add
a detail control. Once a relationship resolves, the Linked Tasks section appears
with its existing relationship controls.

This changes presentation only. Relationship storage, linking actions,
relationship suggestions, and the existing-task catalog remain unchanged.

## Consequences

- Task Details remain focused on meaningful task context by default.
- People can still create or link a relationship from Add a detail.
- iOS and macOS share the same empty-state disclosure rule.
