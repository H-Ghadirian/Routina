# 0003: Resolve Exact-Time Missed Assumptions as Done, Missed, or Canceled

## Status

Accepted

## Date

2026-05-09

## Supersedes

Partially supersedes [0002](0002-exact-time-routines-miss-after-day.md).

## Context

Exact-time routines can only happen at their scheduled occurrence, so an uncompleted occurrence becomes a missed assumption after the scheduled day passes. That assumption is useful for surfacing the item, but it should not remain in front of the user forever once they have clarified what actually happened.

The user may have completed the occurrence, truly missed it, or intentionally canceled it. Missed and canceled outcomes should preserve history without counting as completions.

## Decision

Routina keeps unresolved exact-time missed occurrences visible until the user resolves the assumption as one of three outcomes:

- Done: records a normal completion for the scheduled occurrence timestamp.
- Missed: records a missed log for the scheduled occurrence timestamp.
- Canceled: records a canceled log for the scheduled occurrence timestamp without canceling the recurring routine itself.

Resolved missed and canceled occurrences consume the scheduled slot for presentation and scheduling, but they do not increase completion counts. Done, missed, and canceled logs all belong in timeline activity, stats, and timeline filters.

## Consequences

- The Missed section contains only unresolved assumptions.
- Confirmed missed and canceled occurrences leave the Missed section and return the routine to normal list placement based on its next due date.
- The timeline replaces the older "Dones" framing where the surface includes done, missed, and canceled outcomes.
- Stats expose done, missed, and canceled counts separately while activity charts include all three outcomes.
- Missed styling remains distinct from red overdue styling; canceled outcomes use cancellation styling.
