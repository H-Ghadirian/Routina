# 0155: Link Away Activity in the Planner

## Status

Accepted

## Date

2026-06-04

## Context

Away sessions and completed routine activity can describe the same real-life period. For example, the user may start Away before exercise, then complete an Exercise task when they return. Rendering both records as separate timed blocks makes the planner look like the user did two overlapping things, even though one was the protected container for the other.

## Decision

When completed timeline activity overlaps an Away session in the Day Planner, Routina keeps the underlying Away session and routine log separate, but links them in planner presentation. The Away block adopts the overlapping activity name and emoji where useful, and the overlapping automatic activity suggestion is suppressed so the planner shows one block instead of two.

This is a presentation rule, not a data migration or destructive merge. Timeline history and task completion history remain intact.

## Consequences

- The planner avoids overlapping Away/activity cards for the same real-world period.
- Away blocks can communicate what the user was away for, such as `Away · Exercise`.
- Users still keep independent Away stats and task completion history.
