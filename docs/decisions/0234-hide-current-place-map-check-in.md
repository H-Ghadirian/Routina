# 0234: Hide Current Place Map Check-In

## Status

Accepted

## Date

2026-06-13

## Refines

- [0233: Allow Selected Saved-Place Check-In](0233-allow-selected-saved-place-check-in.md)

## Context

Selected saved-place markers and pinned known places can offer Check In so users can manually check in away from their current device location. When the selected or pinned place is also the place currently matched by device location, showing another Check In action is redundant and can imply the user needs to check in again.

## Decision

The Places map hides Check In for selected or pinned saved places that match the user's current resolved place. It still offers Check In for selected or pinned saved places away from the current resolved place. Add Place remains unavailable for known saved-place coordinates.

## Consequences

- Selecting Home while the device location is already at Home does not offer a duplicate check-in action.
- Selecting another saved place, such as a store away from the current location, still offers Check In.
- Current-location and manual-away-place check-in semantics stay distinct.
