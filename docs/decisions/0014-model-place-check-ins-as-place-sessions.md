# 0014: Model Place Check-Ins as Place Sessions

## Status

Accepted

## Date

2026-05-10

## Context

Users want to record where they are with time and date so they can later analyze how they spend time across home, work, errands, commute, exercise, and other places.

Point-in-time check-ins are fast, but analysis needs durations. A check-in at a new place should therefore close the previous place interval and start a new one instead of producing isolated dots that require later reconstruction.

## Decision

Routina stores check-ins as `PlaceCheckInSession` records with a start time, optional end time, place snapshot, optional linked `RoutinePlace`, and optional activity tag.

Checking into a place ends any active place session and starts a new active session. Checking into the same active place updates the active session instead of duplicating it. Ending the current check-in closes the active session without requiring a new place.

Place check-ins appear as timeline entries and are included in backup, import, local reset, and watch sync flows. The primary capture UI stays manual-first: iPhone and Mac show a compact check-in dock using saved places, and Apple Watch syncs recent places for one-tap check-ins.

## Consequences

- Place history is duration-oriented, so future stats can aggregate time by place and activity without guessing intervals.
- Saved places remain the source of truth for check-in choices; the session stores the place name snapshot so history remains readable if a place is later deleted.
- Watch check-ins depend on the iPhone sync bridge and may use cached places while the phone is temporarily unreachable.
- Future planner or stats work should treat place sessions as timeline evidence, distinct from planned blocks, sleep sessions, and focus sessions.
