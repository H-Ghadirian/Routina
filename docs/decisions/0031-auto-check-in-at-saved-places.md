# 0031: Auto Check In at Saved Places

## Status

Accepted

## Date

2026-05-12

## Supersedes

[0026: Require an Explicit Saved-Place Check-In Action](0026-require-explicit-saved-place-check-in-action.md)

## Context

Manual saved-place check-ins keep browsing non-mutating, but they miss the common case where a device already knows it is inside a saved place. Users should not have to press a check-in control every time they arrive somewhere already modeled in Routina.

Automatic capture still needs a visible audit trail. Users should be able to distinguish device-created sessions from manually started sessions and explicitly confirm them from the row they are reviewing.

## Decision

When a device has an authorized current location and that coordinate falls inside a saved `RoutinePlace`, Routina automatically starts a `PlaceCheckInSession` for that saved place. Moving into a different saved place closes the prior active place session and starts a new automatic session. Leaving saved places closes an active automatic place session, but does not close a manually started active session.

Automatic sessions keep an automatic capture mode and optional confirmation timestamp. Place check-in history rows show an Auto label for automatic sessions. Pending automatic sessions can be confirmed from the row: Mac exposes confirmation in the row context menu, and iOS exposes it through the row swipe action.

Saved-place rows remain non-mutating selection targets for map focus. Explicit check-in controls still exist for manual correction and for current-location sessions outside saved places.

## Consequences

- Saved places can produce passive timeline evidence when the app already has location access.
- Automatic sessions are visible and reviewable rather than silently becoming manual history.
- Confirming an automatic session records user review without erasing that it was device-created.
- The app avoids creating automatic raw current-location sessions outside saved places.
