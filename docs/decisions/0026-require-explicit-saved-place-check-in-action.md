# 0026: Require an Explicit Saved-Place Check-In Action

## Status

Accepted

## Date

2026-05-12

## Context

The Places saved-place list appears beside the map and supports both browsing places and recording a check-in. Treating the full saved-place row as a check-in action makes ordinary selection risky: a user can accidentally mutate place history while only trying to inspect a saved place on the map.

## Decision

Saved-place rows in the Places map flow select and focus the place on the map. Starting a saved-place check-in requires an explicit check-in control in the row or another dedicated check-in control.

## Consequences

- Browsing saved places is non-mutating by default.
- Check-ins remain fast, but they are attached to an explicit action target.
- Future Places UI should avoid making broad row selection implicitly write `PlaceCheckInSession` records.
