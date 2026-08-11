# 0540: Group iOS Task Reviews Under More Destination

## Status

Accepted

## Date

2026-08-11

## Refines

[0033 Use an App-Owned iOS More Tab](0033-use-app-owned-ios-more-tab.md),
[0473 Use Guided iOS Missing-Metadata Procedures](0473-use-guided-ios-missing-metadata-procedures.md),
[0475 Separate Guided Importance and Urgency Reviews](0475-separate-guided-importance-and-urgency-reviews.md),
[0478 Add Guided iOS Thinking Needed Review](0478-add-guided-ios-thinking-needed-review.md),
[0480 Add Guided iOS Time Estimates](0480-add-guided-ios-time-estimates.md),
and [0481 Learn Task-Choice Tie-Breaks After Metadata Readiness](0481-learn-task-choice-tie-breaks-after-metadata-readiness.md).

## Context

Compact iOS More had grown six top-level task-review rows: task choice plus
five focused missing-detail procedures. Each flow was useful, but the flat
collection made More harder to scan and separated task choice from the
metadata work it may require before it can make a recommendation.

## Decision

Compact iOS More exposes one `Review tasks` destination. That screen puts
`Help me choose` first, followed by an `Add missing task details` group for
Pressure, Thinking needed, time estimates, Importance, and Urgency.

The Review tasks screen uses the existing app-owned More navigation stack and
native navigation links for its child procedures. It keeps the normal back
path from an individual procedure to Review tasks and then More. The existing
procedure reducers, lifecycle eligibility, bounded presentation work, and
Home task-detail delegates remain unchanged.

## Consequences

- More has one clear task-review entry instead of six competing root actions.
- Task choice and the missing details it depends on are discoverable together.
- Existing guided-review state and data behavior do not need a migration or
  duplicate navigation coordinator.
