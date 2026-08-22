# 0631: Remove Apple Intelligence Task Relationship Suggestions

## Status

Accepted

## Date

2026-08-21

## Revises

- [0486 Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)
- [0630 Compose Task Relationships With Grouped Sentence Fragments](0630-compose-task-relationships-with-grouped-sentence-fragments.md)

## Supersedes

- [0488 Prioritize Grounded Task Relationship Analysis](superseded/0488-prioritize-grounded-task-relationship-analysis.md)
- [0491 Keep Dismissed Relationship Feedback Local and Fingerprint Scoped](superseded/0491-keep-dismissed-relationship-feedback-local-and-fingerprint-scoped.md)
- [0493 Prioritize Actionable Relationship Proposals in Mac Review](superseded/0493-prioritize-actionable-relationship-proposals-in-mac-review.md)
- [0506 Make Apple Intelligence Relationship Suggestions macOS-Only](superseded/0506-make-apple-intelligence-relationship-suggestions-macos-only.md)
- [0512 Present Mac Relationship Suggestions in the Link Task Sheet](superseded/0512-present-mac-relationship-suggestions-in-link-task-sheet.md)

## Context

Repeated use with real task catalogs showed that Apple Intelligence relationship
suggestions were mostly poor even after Routina prioritized precision, removed
zero-signal candidates, rejected generic reasons, limited proposal counts, and
remembered dismissed pairs. Those controls could constrain model input and output,
but they could not verify whether a proposed relationship or its direction was
actually true. Dismissal also suppressed only the unchanged pair; it did not teach
the system a broader preference or improve later model judgment.

Task relationships are behavior-bearing data. A confirmed dependency can mark a
task Blocked, and completion relationships can affect another routine's outcome.
A discovery feature that routinely asks a person to reject plausible but incorrect
structure creates review work and weakens trust instead of reducing effort.

## Decision

Routina removes Apple Intelligence task-relationship suggestions from the app.
The Mac Link Task sheet is manual-only, and the Routinam application menu no longer
offers a relationship-review window. The on-device Foundation Models request,
candidate discovery and validation policy, suggestion reducer state, batch-review
workflow, review progress fingerprints, and dismissal feedback implementation are
removed with their dedicated tests.

Manual task relationships remain fully supported on iOS and macOS. The shared
composer keeps all seven relationship meanings, presents them as grouped sentence
fragments from the current task's perspective, stages an existing-task choice,
explains its directional consequence, and waits for `Add Relationship`. Creating
and linking a new task remains available from the same focused flow.

Relationship persistence, inverse links, synchronization, derived Blocked state,
Task Ladder placement suggestions based on already confirmed links, automatic
fulfillment, and optional fulfillment do not change. Existing device-local review
fingerprints or dismissal payloads are ignored as inert cache data; they are not
task relationships and were never synchronized.

## Consequences

- People no longer spend attention reviewing low-quality inferred task structure.
- Relationship creation is deliberate and has the same meaning on iOS and macOS.
- Routina no longer depends on Apple Intelligence availability for task linking.
- Large task catalogs rely on manual search and explicit selection instead of
  speculative discovery.
- A future suggestion feature requires a separate accepted decision and evidence
  from a representative evaluation set that it meets a high-precision trust bar.
