# 0488: Prioritize Grounded Task Relationship Analysis

## Status

Superseded

## Date

2026-08-06

## Superseded By

- [0631 Remove Apple Intelligence Task Relationship Suggestions](../0631-remove-apple-intelligence-task-relationship-suggestions.md)

## Refines

[0486 Suggest Confirmed Task Relationships On Device](../0486-suggest-confirmed-task-relationships-on-device.md)

## Context

The first relationship-review request bounded the model input but still filled a
large catalog's candidate limit with alphabetically ordered tasks when there was
little useful overlap. Generic action words such as `prepare` or `review` could
also look like a connection. That combination invites plausible-sounding,
topical suggestions that are not useful task relationships.

## Decision

Relationship analysis optimizes for precision over suggestion volume. A request
contains at most eight active, unlinked candidates. When the eligible catalog
fits within that bound, the model may inspect all of it. For a larger catalog,
only candidates with a positive discovery signal enter the request: a shared
normalized tag, custom-section path component, or specific work word. Generic
action words and words that occur across a substantial portion of the active
catalog do not count as specific work evidence. The request therefore never
fills its remaining slots with arbitrary zero-signal tasks.

The on-device model is told that the shortlist is not a recommendation and to
prefer no result over a speculative result. It can propose at most three links.
Every proposal reason must point to a concrete task detail from the source or
candidate, such as a named deliverable, material, approval, input, step, or
outcome. Routina rejects output whose reason has no concrete word from either
task, even when its task ID and relationship kind are otherwise valid.

The relationship-review fingerprint advances to the second analysis-policy
version. This intentionally makes earlier reviewed tasks appear changed, giving
the person one opportunity to run the improved analysis through `Analyze new &
changed`. It does not alter any task or relationship data.

Manual linking remains the way to create a relationship when a meaningful task
is outside the focused shortlist. A shared tag, path, or any candidate-selection
signal still never proves a relationship and every accepted proposal still
requires individual confirmation.

## Consequences

- Large lists spend the model's context on task pairs with evidence rather than
  arbitrary filler candidates.
- Relationship review produces fewer weak suggestions and clearer reasons, at
  the intentional cost of omitting some low-context relationships.
- Existing review progress refreshes once so people can benefit without editing
  every task.
- The app continues to treat model output as untrusted and preserves manual,
  confirmation-based relationship control.
