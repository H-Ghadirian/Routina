# 0479: Use Bounded Pairwise Comparisons for iOS Task Choice

## Status

Accepted

## Date

2026-08-06

## Refines

[0424 Make Task Detail Priority Optional](0424-make-task-detail-priority-optional.md),
[0468 Model Task Thinking Needed Separately](0468-model-task-thinking-needed-separately.md),
and [0476 Keep Guided Review Card and Detail Work Bounded](0476-keep-guided-review-card-and-detail-work-bounded.md)

## Context

Importance, Urgency, Pressure, Thinking needed, and duration describe useful
task properties, but they do not by themselves answer which task a person
should do in their current condition. A full pairwise or bubble-sort ranking of
hundreds of tasks would also require an unreasonable number of comparisons and
would make a temporary decision feel like permanent task administration.

## Decision

Compact iOS More includes `Help me choose`. A person first chooses available
time, current energy, and an immediate intent: reduce pressure, meet urgency,
or make progress. The reducer fetches currently selectable tasks (not canceled,
paused, snoozed, or complete for their current period), derives a
stable condition-aware shortlist of at most six candidates, and retains only
that small presentation set for the session. It favors tasks that fit the
chosen time and energy, while the intent weights existing Importance, Urgency,
or Pressure metadata.

The first comparison favors candidates with matching Importance, Urgency,
Pressure, and Thinking needed values, so pairwise choice resolves meaningful
ties before moving to less-similar options. The flow is a bounded sequential
tournament, not a bubble sort: each answer keeps the preferred task as the
current winner against the next candidate, for no more than five comparisons.
It then recommends the winner and can open existing Task Details.

Choices are session-only. They never overwrite Importance, Urgency, Pressure,
Thinking needed, Priority, duration, planning, scheduling, or task order. The
feature is iOS-only for this MVP, and its SwiftData loading stays in the reducer
rather than the SwiftUI view.

## Consequences

- A person can get a current-context recommendation without maintaining a
  global manual ranking.
- Pairwise comparison remains practical at high task volume because the
  session is bounded to six candidates and five answers.
- Durable metadata keeps its descriptive meaning; a temporary preference does
  not silently redefine task priority.
