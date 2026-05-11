# 0016: Show Place Check-Ins as a Day Timeline

## Status

Accepted

## Date

2026-05-10

## Context

Map check-ins answer "where am I now," but users also need to review how their location changed through a day. The regular timeline can list place sessions, yet the map check-in surface is the most direct place to connect those sessions with coordinates.

## Decision

The map check-in sheet includes a Places/Day switch. Places remains optimized for checking in; Day shows the selected day's place sessions in chronological order with ranges, durations, active state, activity tag, and a map-focus action when the session has coordinates.

## Consequences

- Users can verify the day's location history immediately after checking in.
- Stored coordinate snapshots become visible and useful without waiting for a dedicated analytics screen.
- The day timeline stays read-only for now; editing, merging, or promoting raw current-location sessions can be added later.
