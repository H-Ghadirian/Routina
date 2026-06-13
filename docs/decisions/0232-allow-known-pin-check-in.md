# 0232: Allow Known Pin Check-In

## Status

Accepted

## Date

2026-06-13

## Refines

- [0230: Unify Map Pin Place and Check-In Actions](0230-unify-map-pin-place-and-check-in-actions.md)

## Context

The unified map location panel hid both Add Place and Check In when the shown location was inside a saved place. That prevented a user from dropping a pin on a known saved place and checking in there when their current device location was elsewhere.

## Decision

A pinned map location inside a saved place still offers Check In. That check-in uses the pin coordinate and resolves to the containing saved place. Add Place remains unavailable for known saved-place coordinates to avoid duplicate saved places.

Current-location panels can continue to avoid duplicate known-place actions when the shown coordinate is the device's current location rather than an explicit pin.

## Consequences

- Users can check in at a known place from the map even when they are not physically there.
- Saved-place creation stays blocked for coordinates already covered by a saved place.
- The pin action remains distinct from current-location check-in behavior.
