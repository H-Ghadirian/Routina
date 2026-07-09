# 0358 Prefer Current-Day Missed Window Resolution From Home

Status: Accepted

Date: 2026-07-09

Refines: [0003 Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled](0003-resolve-exact-time-missed-assumptions.md), [0348 Allow Selected Past Exact Time Backfills](0348-allow-selected-past-exact-time-backfills.md)

## Context

Time-window calendar routines become missed as soon as their scheduled window ends. A weekly Thursday routine available from 18:30 to 20:00 can therefore show Home row resolution actions at 22:00 on the same Thursday.

Home row resolution previously picked the oldest unresolved missed occurrence first. If older weeks were still unresolved, choosing `I did it` at 22:00 could complete an older Thursday instead of the just-finished window. The row could still look missed afterward, making the action feel like a no-op.

## Decision

When Home row lifecycle actions resolve a missed exact-time or time-window occurrence, they prefer an unresolved missed occurrence on the current reference day. If the reference day has no unresolved missed occurrence, Home keeps the existing oldest-unresolved fallback.

For completion, the current-day missed occurrence can be marked done even when older missed occurrences remain unresolved. Older missed occurrences stay unresolved until the user resolves them separately.

## Consequences

`I did it` after a same-day time window ends records the just-finished occurrence instead of silently resolving older history first.

The Home row may still show missed state if older occurrences remain unresolved, but the user action mutates the occurrence they most likely meant: the one that just ended today.
