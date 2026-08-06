# 0086 — Keep batch AI failures task-scoped

Date: 2026-08-06

## Symptom

`Analyze all tasks` could stop after the first several tasks, commonly appearing
to have a fixed ten-task limit even though the batch contained many more tasks.
Partial suggestions hid the fatal batch message, so the failed source task was
not visible to the person reviewing results.

## Root Cause

The sequential batch wrapped every model request in one fail-fast operation. A
content-specific model or guardrail error for any source task terminated the
entire loop instead of belonging to that task. The result summary represented
only completed requests and did not distinguish a failed task from an unfinished
batch.

## Fix

Each source-task model request now catches recoverable errors independently,
records that task as needing retry, increments batch progress, and continues to
the next source. The Mac review UI shows failure counts and marks affected task
rows. Cancellation and unavailable Apple Intelligence remain batch-level exits.

## Prevention Rule

In a user-requested batch over independent entities, scope recoverable processing
errors to the current entity. Continue the batch, make failures visible and
retryable, and reserve fail-fast behavior for infrastructure that makes every
remaining operation impossible.

## Regression Safeguard

`TaskRelationshipReviewFeatureTests.analyzeAllContinuesAfterOneTaskModelFailure`
injects a model error for the middle task and verifies that the final task is
still analyzed, full progress is reached, and the failed task remains unchecked
with a visible retry reason.
