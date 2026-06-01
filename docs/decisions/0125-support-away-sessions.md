# 0125: Support Away Sessions

## Status

Accepted

## Date

2026-06-01

## Context

Some protected time is not focus work or sleep. Waking up, stepping outside, eating, winding down, or taking an intentional reset needs a timer and phone/app blocking, but counting it as focus would distort productivity stats and task history.

## Decision

Routina models these periods as first-class `AwaySession` records. An Away session has a preset, title, planned duration, completion or early-end timestamp, and extension count. Active Away does not overlap with Sleep or Focus timers, and Focus timers cannot start while Away is active.

Active Away reuses the existing focus shield/blocking configuration so the same selected apps, categories, and websites are protected without adding a second blocker preference surface. Away sessions appear as protected blocks in the Day Planner, contribute to dedicated Away stats, and are included in backup, import, reset, duplicate cleanup, and device action logs.

## Consequences

- Away time remains visible and reviewable without inflating Focus metrics or task completion history.
- Users can use the same blocker setup for focus work and away-from-phone time.
- Backup schema version 30 preserves Away session history.
- Planner placement logic treats Away intervals as blocked time, matching Sleep protection semantics.
