# 0598: Count Semantic Focus Session Copies Once in Stats

## Status

Accepted

## Date

2026-08-16

## Context

Stats derives focus totals from persisted task, tag, unassigned, and board focus
sessions. Synchronization can temporarily or historically preserve several rows
with different storage IDs for one logical session. Planner storage separately
deduplicates matching timed placements, so Calendar can show the correct focus
segments while Stats multiplies the same underlying focus time.

A reported day showed about six hours of visible tag-focus segments in Calendar
but `36h 6m` in Stats, consistent with six semantic copies of the same three
second-precision sessions.

## Decision

Stats canonicalizes focus records before deriving focus evidence. Task, tag,
and unassigned records with the same focus identity and exact start time count
as one logical session even when their storage IDs differ. Board-focus records
use sprint and exact start time as their semantic identity. Duration charts,
hourly rhythm, goal focus, Focus 2048, and task-focus achievements consume the
relevant canonicalized inputs.

When copies disagree, Stats prefers the record with the latest accepted
activity, then a terminal record over an active record. If an unassigned record
and its board-converted replacement share an ID during synchronization, the
board record wins. This is a presentation canonicalization and does not delete
persisted history.

Completed sessions retain the completion-day bucketing established by
[0118](0118-show-focus-chart-details-and-grouping.md) and
[0137](0137-show-active-focus-in-stats-today.md).

## Consequences

- Exact synchronized copies cannot multiply one day's focus total or Focus 2048
  progress.
- Focus duration, hourly rhythm, goal focus, and task-focus achievements use
  the same canonical task-focus identity; board focus is also canonicalized in
  the duration and hourly evidence that includes it.
- Distinct sessions for the same task or tag remain distinct when their start
  times differ.
- Existing persisted rows remain available for synchronization and repair;
  this decision changes derived Stats evidence, not storage.
