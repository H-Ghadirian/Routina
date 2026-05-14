# 0039: Move Mac Check-In to the Home Toolbar

## Status

Accepted

## Date

2026-05-14

## Context

The Mac Home sidebar previously carried a large bottom check-in dock. That made place capture visible, but it consumed task-list space and competed with sidebar content. Sleep already lives in the Home toolbar as a small global action.

## Decision

Mac Home exposes place check-in as a compact toolbar menu beside the sleep button. The menu keeps the important capture actions: open Places/map, choose an activity, check in at suggested saved places, show the active place, and end the active check-in.

The Mac sidebar no longer renders the large bottom check-in dock. iPhone keeps its platform-owned bottom dock until a separate mobile navigation decision changes it.

## Consequences

- Place capture remains globally reachable from Home without occupying sidebar space.
- The active place is still visible in compact form, while detailed map and history review stay in Places.
- Future Mac global Home actions should continue to live in the root toolbar when they are independent of the current sidebar content.
