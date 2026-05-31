# 0116: Show Focus Blocks

## Status

Accepted

## Date

2026-05-31

## Context

Count-up focus timers are intentionally low pressure, but a running stopwatch alone does not give users a satisfying sense of progress. Users want visible proof that focus time is accumulating while the timer is still open, and they want the earned focus time to remain visible later.

## Decision

Task focus UI represents focus time as five-minute blocks. During a count-up task focus session, Routina shows a current-session block grid with empty upcoming blocks; one block becomes filled after each full five minutes of elapsed focus. The current session also shows the next five-minute boundary.

Completed task focus history shows accumulated filled blocks for that task. Accumulated blocks are derived from completed `FocusSession` durations by counting whole five-minute blocks per session; active count-up display adds the current session's whole blocks to that completed total. Focus blocks are presentation derived from focus history and do not add new persistence.

## Consequences

- Count-up focus gains visible progress without turning into a deadline.
- Short sessions below five minutes remain tracked as focus time but do not fill a block.
- Existing focus statistics, planner syncing, and focus history storage remain unchanged.
