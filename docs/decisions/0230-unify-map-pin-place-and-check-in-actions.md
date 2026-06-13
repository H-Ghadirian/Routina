# 0230: Unify Map Pin Place and Check-In Actions

## Status

Accepted

## Date

2026-06-13

## Refines

- [0015: Support Map-Based Place Check-Ins](0015-support-map-based-place-check-ins.md)
- [0029: Create Saved Places From the Map](0029-create-saved-places-from-map.md)

## Context

The Places map can create a saved-place draft by dropping a pin, and it can also start raw coordinate check-ins. Showing separate map panels for those related actions made a selected pin feel like two competing workflows instead of one location decision.

## Decision

A map location owns one panel. That panel offers two direct actions: add a saved place at the shown coordinate or check in there. For dropped pins, the check-in action uses the pin coordinate, not the device's current location, and still resolves to a containing saved place when one exists.

Current-location controls should use the same panel shape rather than a separate title badge plus an independent check-in panel. The panel does not use an Add Place / Check In tab switch or a cancel button. If the shown location is already inside a saved place, the panel is informational only and does not offer Add Place or Check In actions.

## Consequences

- Users choose what to do with one unsaved map location from one panel with direct action buttons.
- Known saved-place locations avoid duplicate check-in or add-place actions.
- The map avoids duplicate overlays for add-place and check-in actions.
- Raw coordinate check-ins and saved-place creation keep their existing data model behavior.
