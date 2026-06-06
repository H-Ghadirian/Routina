# 0163: Name Raw Current-Location Check-Ins Opportunistically

## Status

Accepted

## Date

2026-06-06

## Refines

- [0015: Support Map-Based Place Check-Ins](0015-support-map-based-place-check-ins.md)
- [0023: Edit Place Check-Ins from the Day Timeline](0023-edit-place-check-ins-from-day-timeline.md)

## Context

Map-based check-ins can record a raw current-location session when no saved place contains the device coordinate. Those sessions were previously named `Current Location`, which keeps capture fast but makes history and the active check-in toolbar less meaningful.

Forcing a naming prompt before saving would add friction to a habit-forming quick action. The better behavior is to save immediately, use the best local name Routina can infer, and then offer a lightweight way to name or save the location afterward.

## Decision

Raw current-location check-ins save immediately without a blocking prompt. When no containing saved place is found, Routina gives the session a local best-effort name:

- Reuse a nearby previously user-named raw location when one exists.
- Otherwise use `Near <saved place>` when a saved place is close but outside its check-in radius.
- Otherwise use a time-based fallback such as `Check-in at 14:32`.

After a raw current-location check-in from the map flow, Routina keeps the map UI open and shows the existing add-place panel at that coordinate. The user can name and save the location, or dismiss the panel. Saving the place links the source check-in to the new saved place while preserving the measured coordinate snapshot.

The day timeline also exposes `Save as Place` for raw coordinate check-ins, so older unnamed or time-named sessions can be promoted later.

## Consequences

- Place check-ins remain fast and non-blocking.
- Active raw check-ins and history rows are more readable than `Current Location`.
- Users can gradually turn repeated raw locations into saved places without pre-configuring them.
- The naming logic intentionally uses only local Routina data and does not add reverse-geocoding or network dependencies.
