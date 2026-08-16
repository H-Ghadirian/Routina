# 0596: Advance Repeating Blocked-By Chains by Completion Order

## Status

Accepted

## Date

2026-08-16

## Revises

- [0486: Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0593: Show Relationship Blocking in Home Task Rows](0593-show-relationship-blocking-in-home-task-rows.md)

## Context

`Blocked by` originally resolved a repeating prerequisite only while that task's
current presentation status was Done. This works for a simple current-period
check but not for a repeating workflow chain. A cadence-free prerequisite can
become available again immediately after completion, and pausing it to keep the
finished step out of the active list changes its status to Paused. Either change
could make the dependent task Blocked again even though the prerequisite had
already completed the chain's current step.

For a repeating chain such as `A blocked by B`, completion is a handoff. B's
completion should unlock A until A completes. A's completion then begins the
next pass through the chain, which must wait for a newer B completion.

## Decision

A confirmed `Blocked by` prerequisite is resolved when its latest recorded
completion or fulfillment is newer than the dependent task's latest recorded
completion. If the dependent has never completed, any recorded prerequisite
completion resolves the first pass through the chain.

That resolution remains effective when the prerequisite immediately becomes
available for another repetition or is subsequently paused. Once the dependent
records a newer completion, the earlier prerequisite completion is consumed and
the dependent is blocked again until the prerequisite completes again. With
multiple prerequisites, every prerequisite must be resolved for the current
dependent pass.

Completed or canceled one-off prerequisites remain permanently resolved.
Synthetic assumed-done occurrences without a persisted completion timestamp
retain their current-occurrence resolution behavior.

The rule is derived from synchronized completion history and task summaries; it
does not add mutable latch state to relationships. Home resolves the task graph
once while rebuilding its display snapshot and uses its already-cached
completion dates. Task Details and Help me choose use the same shared resolver
and provide their loaded completion history.

Repeating dependent rows may present the relationship-derived `Blocked` Status
Badge, just as one-off rows do, until their prerequisite handoff is satisfied.

## Consequences

- Repeating workflows advance in completion order without requiring pause as a
  workaround or losing the handoff when a task recurs immediately.
- Completing A consumes B's earlier completion, so the next A occurrence cannot
  skip ahead without another B completion.
- Pausing B before it completes still leaves A blocked; only recorded completion
  or fulfillment earns the handoff.
- Undoing or synchronizing completion history naturally recalculates the chain
  without repairing relationship records.
- Relationship derivation remains outside scrolling render paths.
