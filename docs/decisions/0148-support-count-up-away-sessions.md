# 0148: Support Count-Up Away Sessions

## Status

Accepted

## Date

2026-06-03

## Context

Away sessions started as fixed protected timers with a planned duration. That works for short, intentional windows, but some away-from-phone periods should simply start now and end when the user returns. Requiring a duration adds friction and can make a session auto-complete before the user is actually back.

Focus sessions already use a non-positive planned duration to represent count-up timers. Reusing that convention keeps session storage simple and avoids a SwiftData migration.

## Decision

Away sessions can be started either with a fixed planned duration or as a count-up session. Count-up Away stores `plannedDurationSeconds` as `0`, has no planned end, does not auto-complete through expiry checks, and finishes at the actual user-ended timestamp.

Count-up Away sessions still reuse Focus shields while active, render in the planner using elapsed protected time, contribute to Away stats and finished Away achievements, and round-trip through backup/import. Planned-duration Away achievement progress counts only completed fixed-duration Away sessions.

## Consequences

- Users can start Away without choosing a duration.
- The existing `AwaySession` storage model can represent both timer styles without a schema migration.
- Planner and stats surfaces continue to derive from actual session duration, while planned-duration-specific achievements remain tied to fixed timers.
