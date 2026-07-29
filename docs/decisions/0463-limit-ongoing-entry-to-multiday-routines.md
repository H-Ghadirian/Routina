# 0463: Limit Ongoing Entry to Multi-Day Routines

## Status

Accepted

## Date

2026-07-29

## Refines

- [0199: Support Multi-Day Routine Start Flow](0199-support-multiday-routine-start-flow.md)
- [0246: Show Multi-Day Ongoing Range](0246-show-multiday-ongoing-range.md)

## Context

Decision 0199 retained the older ongoing lifecycle for Gentle routines while
introducing a first-class Start and Stop lifecycle for multi-day routines.
Only iOS continued exposing that legacy entry point as a secondary
`Start ongoing` button. Mac Task Detail did not show the action, so the same
one-day checklist-driven routine offered different lifecycle commands on each
platform.

The Mac behavior is the product source of truth for this action set. Ongoing
state is meaningful as an explicit user flow for multi-day work, but adds a
second completion lifecycle to ordinary one-day Gentle routines.

## Decision

Task Detail offers entry into the ongoing lifecycle only for multi-day
routines. Their primary action remains `Start` while idle and `Stop` while
active on both iOS and macOS.

One-day routines, including Gentle and checklist-driven routines, do not show
a separate `Start ongoing` action. Existing one-day tasks already carrying a
legacy ongoing state remain compatible and can finish that state; this change
does not discard persisted data.

## Consequences

- iOS and macOS show the same lifecycle actions for one-day routines.
- Checklist completion remains the single completion path for one-day
  checklist-driven routines.
- Multi-day Start, active-range, Stop, and undo behavior is unchanged.
- Future platform-specific Task Detail action additions must be checked
  against the other platform before shipping.
