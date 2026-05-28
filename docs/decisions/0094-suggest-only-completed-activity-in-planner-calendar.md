# 0094: Suggest Only Completed Activity in the Planner Calendar

## Status

Accepted

## Date

2026-05-28

## Supersedes

- The automatic calendar placement portion of [0006](0006-make-planner-timeline-activity-configurable.md) that allowed missed and canceled timeline activity to appear as planner calendar suggestions.

## Context

Planner timeline activity includes completed, missed, and canceled outcomes so users can review what happened on a day. The planner calendar suggestion layer has a narrower job: it proposes activity that can sensibly be confirmed into the plan.

Missed and canceled outcomes are historical evidence, but placing them as suggested calendar blocks can make the planner feel like it is recommending work that did not happen or was explicitly canceled.

## Decision

Automatic planner calendar suggestions are derived only from completed timeline activity. Missed and canceled timeline logs, plus legacy cancellation timestamps, remain timeline history and can still participate in non-suggestion review surfaces where those surfaces intentionally show timeline activity.

Confirmed automatic suggestions still create persisted planner blocks without rewriting timeline history. Hidden suggestion storage still applies to eligible automatic suggestions.

## Consequences

- Canceled and missed tasks no longer render as automatic blocks on the planner calendar.
- Completed tasks continue to use finish-time placement and overlap avoidance.
- The broader timeline model continues to distinguish completed, missed, and canceled outcomes for history, stats, and review workflows.
