# 0233: Allow Selected Saved-Place Check-In

## Status

Accepted

## Date

2026-06-13

## Refines

- [0232: Allow Known Pin Check-In](0232-allow-known-pin-check-in.md)

## Context

Known saved-place map markers can be selected directly, not only reached through a dropped pin. After allowing known pins to check in, selected saved-place panels still inherited current-location action rules. That meant selecting a saved place away from the user's current location could show no Check In action.

## Decision

Selecting a saved-place marker on the Places map offers Check In for that saved place. The panel uses the selected place's coordinate and radius context, not the user's current-location status. Add Place remains unavailable for selected saved places.

## Consequences

- Users can check in at a saved place from its map marker even when their current location is elsewhere.
- Current-location status no longer controls selected saved-place actions.
- Saved-place duplication stays blocked from selected saved-place panels.
