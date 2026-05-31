# 0123: Pause Focus Timers

## Status

Accepted

## Date

2026-05-31

## Context

Focus timers can now encourage longer sessions with blocks and achievement badges, but real focus time can be interrupted. If the timer keeps counting through interruptions, stats, blocks, planner duration, and achievements overstate the time the user actually spent focusing.

## Decision

Task and unassigned `FocusSession` timers can be paused and resumed while remaining the active focus session. A paused session stores `pausedAt` plus accumulated paused seconds, and all elapsed, remaining, block, planner, widget, Live Activity, Watch, stats, and achievement calculations derive focus duration from active time rather than wall-clock time.

Finishing or abandoning a paused focus session closes the current pause first so the final duration excludes the paused interval. While a session is paused, focus shields are suspended because the user is no longer actively focusing; resuming the session reapplies shields from the existing focus settings.

## Consequences

- Users can handle interruptions without losing the session or inflating focus history.
- Count-up focus blocks fill only from actual focused minutes.
- Count-up planner blocks are saved with focused minutes, not wall-clock elapsed time.
- Paused sessions still block starting another task focus timer until they are resumed and finished, or abandoned.
