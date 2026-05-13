# 0036: Treat Completion Times as Planner Finish Times

## Status

Accepted

## Date

2026-05-13

## Context

The day planner shows automatic timeline activity for tasks that were done, missed, or canceled on a date. Completed tasks were previously rendered as if the completion timestamp was the block's start time.

When a user marked several tasks done in quick succession, those automatic blocks all started at nearly the same minute and visually stacked on top of each other. The user expectation is that pressing Done records when a task finished, not when it started.

## Decision

Completed automatic timeline activity in the day planner treats the done timestamp as the activity finish time. The rendered block starts at `finish - duration`, using the actual duration when available, then the estimate, then the default duration.

When completed activities are close enough to overlap, the planner arranges them backwards from the latest completion so they appear one after another instead of stacked. Existing persisted planner blocks are treated as occupied time, so automatic completed activity is placed before confirmed or manually placed work instead of on top of it.

Missed and canceled automatic activity keeps its existing timestamp placement.

## Consequences

- Rapidly completed tasks no longer overlap in the planner merely because their Done taps happened close together.
- Completed automatic blocks better represent work as having ended at the recorded completion time.
- Confirming an automatic completed activity preserves the non-overlapping rendered time range as the persisted planner block.
- Confirming one automatic activity does not cause earlier automatic completions to recalculate over the newly confirmed block.
