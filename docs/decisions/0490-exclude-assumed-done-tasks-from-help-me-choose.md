# 0490: Exclude Assumed-Done Tasks From Help Me Choose

Status: Accepted

Date: 2026-08-06

Refines: [0481 Learn Task-Choice Tie-Breaks After Metadata Readiness](0481-learn-task-choice-tie-breaks-after-metadata-readiness.md), [0486 Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md), and [0489 Expand Auto-Assume Done to Scheduled Repeats](0489-expand-auto-assume-done-to-scheduled-repeats.md)

## Context

An assumed-done occurrence represents work Routina expects to be complete until the person confirms or rejects it. Recommending that work in `Help me choose`, or requiring missing ranking metadata for it, contradicts that provisional completed state.

## Decision

`Help me choose` excludes a task whenever its current occurrence is synthetically assumed done. The exclusion uses the shared assumed-completion derivation, including the occurrence date and any recorded completion, cancellation, or missed resolution. It runs before relationship blocking, missing-metadata counts, comparisons, and ranking.

## Consequences

- Assumed-done tasks do not consume a comparison slot or become a recommendation.
- Their missing task-choice metadata does not block a recommendation for work that remains actionable.
- A task becomes eligible again when its current occurrence is no longer assumed done, such as after a new occurrence begins or an assumed occurrence is resolved as missed.
