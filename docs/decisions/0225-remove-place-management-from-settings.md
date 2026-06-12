# 0225: Remove Place Management Sections from Settings → Places

## Status

Accepted

## Date

2026-06-12

## Context

The Settings → Places screen currently includes all of:

- A form to add new places (name, kind, map pickers, and save action).
- A full “Saved Places” list with delete actions.

This duplicates the place creation and management flow already present on the main Places surface.

## Decision

Keep Settings → Places focused on operational behavior only (location status, automatic check-in preferences, and status output), and move place add/edit/delete and saved place browsing into dedicated Places surfaces.

## Consequences

- Users cannot add or remove saved places from Settings → Places.
- Add/edit/remove saved place actions remain available through map/check-in flows where place management is already presented.
- Settings → Places remains a simpler configuration surface for place-related automatic behavior and permissions.
