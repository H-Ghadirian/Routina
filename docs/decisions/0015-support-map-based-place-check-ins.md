# 0015: Support Map-Based Place Check-Ins

## Status

Accepted

## Date

2026-05-10

## Context

Place check-ins started as a manual saved-place capture flow. Users also need to check in from a map or from the device's current location, especially before they have built a complete saved-place list.

Analysis should remain durable if a saved place is later renamed, moved, or deleted. A session therefore needs enough location context to stay meaningful beyond its current `RoutinePlace` link.

## Decision

Place check-in sessions store optional coordinate snapshots. Saved-place check-ins snapshot the place center and radius; current-location check-ins store the measured coordinate and horizontal accuracy.

The iPhone and Mac check-in dock includes a map button. The map sheet requests current location, shows saved place radii, highlights the current position, orders saved places by proximity when possible, and checks into the containing saved place when the current coordinate falls inside one. If no saved place contains the coordinate, Routina records a raw "Current Location" session. When location access is not usable, the map flow offers a direct path to the platform's location permission settings.

## Consequences

- Users can start tracking location time without pre-configuring every place.
- Future timeline or stats surfaces can map and aggregate sessions using stored coordinates instead of relying only on mutable saved-place records.
- Location access remains user-initiated from the check-in UI; manual saved-place check-ins still work when permission is denied or unavailable.
- Users can recover denied, restricted, or disabled location access from the check-in flow without hunting through system preferences.
- Raw current-location sessions are intentionally named generically until a future editing flow lets users promote or rename them.
