# 0512: Present Mac Relationship Suggestions in the Link Task Sheet

## Status

Accepted

## Date

2026-08-08

## Refines

- [0486 Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)
- [0506 Make Apple Intelligence Relationship Suggestions macOS-Only](0506-make-apple-intelligence-relationship-suggestions-macos-only.md)

## Refined By

- [0630 Compose Task Relationships With Grouped Sentence Fragments](0630-compose-task-relationships-with-grouped-sentence-fragments.md)

## Context

The Mac Linked Tasks card exposed an AI `Suggest` button and explanatory copy
beside the ordinary relationship-management actions. That made a secondary,
asynchronous discovery flow compete with the direct task-detail overview, even
though suggestion results ultimately ask the person to choose task links.

## Decision

Mac Task Details keeps Apple Intelligence relationship suggestions inside the
`Link Task` sheet. The sheet opens in manual-linking mode with its existing
relationship type and searchable task catalog. A separate `Suggest` option
switches the sheet to suggestion mode, hides manual search, starts the existing
bounded on-device request, and visibly shows progress until results, an empty
outcome, or an error arrives.

Suggested relationship cards, type editing, confirmation, and dismissal remain
inside that sheet. The existing confirmation-only persistence rule is unchanged;
manual linking remains immediately available by switching back. The Mac Task
Detail card no longer has a standalone Suggest action or placeholder copy, and
iOS continues to expose neither suggestions nor their status. The dedicated Mac
relationship-review window is unchanged.

## Consequences

- Task Detail stays focused on the current relationship graph and direct actions.
- The loading state appears in the context where suggestion results are reviewed.
- Suggestion requests remain intentional, bounded, macOS-only, and non-mutating
  until a person confirms a proposed link.
