# 0409: Add Manual Can Complete Task Links

Date: 2026-07-19

Status: Accepted

Refines: [0377 Fulfill Routines From Linked Task Completions](0377-fulfill-routines-from-linked-task-completions.md)

## Context

Some task relationships are conditional or judgment-based. A source task can sometimes satisfy another routine, but Routina should not assume that every source completion is enough. Existing `Done when` / `Completes` links are automatic, which is still useful for relationships that are always true.

## Decision

Task links add a manual fulfillment relationship:

- `Can complete` on the source task means this completion may also satisfy the linked target routine.
- `Can be completed by` is the inverse wording from the target routine.

When a user marks a task done from Task Detail and eligible `Can complete` targets exist, Routina asks whether to complete only the source task or also fulfill one or all linked target routines. Selected targets record the same source-attributed `fulfilled` logs used by automatic linked fulfillment, so target routine calendars, streaks, and review state update without double-counting aggregate completed activity.

The existing `Done when` / `Completes` relationship remains automatic.

## Consequences

- Users can model occasional "counts as" relationships without creating silent completions.
- Conditional evidence such as duration can remain a user judgment in v1.
- Home-row Done does not yet show this prompt; Task Detail owns the manual confirmation surface.
