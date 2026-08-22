# 0491: Keep Dismissed Relationship Feedback Local and Fingerprint Scoped

## Status

Superseded

## Date

2026-08-07

## Superseded By

- [0631 Remove Apple Intelligence Task Relationship Suggestions](../0631-remove-apple-intelligence-task-relationship-suggestions.md)

## Refines

[0486 Suggest Confirmed Task Relationships On Device](../0486-suggest-confirmed-task-relationships-on-device.md)
and [0488 Prioritize Grounded Task Relationship Analysis](0488-prioritize-grounded-task-relationship-analysis.md)

## Context

Relationship review already lets a person dismiss a proposed pair, but that
choice lasts only for the open review window. A later explicit reanalysis can
send the unchanged pair to the model again and resurface the same unwanted
proposal. The original review decision's statement that nothing is persisted
before confirmation protected task relationships, but was too broad for this
small, user-authored negative-feedback signal.

## Decision

Dismissal persists device-local feedback, not a task relationship or model
output. Each record stores an unordered pair of task IDs, the current bounded
summary fingerprint for each task, and the dismissal timestamp. It does not
store task text, a model reason, an inferred preference, or the suggested
relationship type; it is never synchronized, exported to the MCP snapshot, or
submitted to the model.

While both fingerprints still match, the pair is excluded before candidate
selection and therefore never enters the on-device model request from either
direction. If either task changes, becomes unavailable, or is no longer
reviewable, the record is removed automatically and the pair becomes eligible
again. A dismissal remains pair-specific: it must not suppress unrelated tasks
or teach a broad rule about task names, tags, paths, or relationship kinds.

Confirmation remains the only operation that writes a task relationship. The
existing review-progress fingerprints continue to be separate device-local
state.

## Consequences

- Dismissed unchanged pairs do not repeatedly consume review attention or
  on-device model work.
- Meaningful task edits reopen the pair for reconsideration without requiring a
  manual reset.
- Local feedback keeps the task graph and sync data unchanged until a person
  explicitly confirms a relationship.
- The feature gains a small versioned UserDefaults payload that must be pruned
  whenever the review catalog loads.
