# 0493: Prioritize Actionable Relationship Proposals in Mac Review

## Status

Accepted

## Date

2026-08-07

## Refines

[0486 Suggest Confirmed Task Relationships On Device](0486-suggest-confirmed-task-relationships-on-device.md)

## Context

The relationship-review sidebar is an audit catalog, but once analysis finds a
small number of proposals, a long list of unchanged green-check rows obscures
the work that still needs a decision. Removing every non-proposal row entirely
would also remove access to retry states and manual selected-task analysis.

## Decision

The Mac review sidebar presents tasks with unresolved relationship proposals
first under `Possible relationships`. All remaining active review tasks appear
afterward in an initially collapsed `Other tasks` group. The group remains
available for retries, new/changed state, failures, and manually selected
analysis, but reviewed-unchanged rows do not show a green completion icon.

Sidebar grouping is a presentation cache maintained outside the scrolling body.
It updates when the immutable task catalog or pending-proposal cache changes;
it does not change review progress, candidate selection, dismissal feedback, or
the task relationship graph.

## Consequences

- Reviewers immediately see the proposals that need confirmation or dismissal.
- The complete audit catalog remains accessible without dominating the window.
- An unchanged task no longer competes visually with relationship decisions.
