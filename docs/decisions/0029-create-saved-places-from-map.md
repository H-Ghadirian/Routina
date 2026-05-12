# 0029: Create Saved Places From the Map

## Status

Accepted

## Date

2026-05-12

## Context

The Places map is already the primary surface for reviewing saved places, check-in history, and the user's current location. Creating a saved place still required leaving that flow for Settings, even when the user can visually identify the intended location directly on the map.

## Decision

The Places map lets users click or tap an empty map location to drop a draft marker. The draft can be named, assigned a radius, and saved as a normal `RoutinePlace`. Taps near existing saved-place markers, check-in history markers, or the current-location marker continue to favor selecting those existing map features instead of creating a new place.

## Consequences

- Saved places can be created in context from the same map used for check-ins and place review.
- Creating a place is still explicit: a dropped draft marker is not persisted until the user names and saves it.
- The saved place uses the same duplicate-name validation and radius bounds as Settings-created places.
