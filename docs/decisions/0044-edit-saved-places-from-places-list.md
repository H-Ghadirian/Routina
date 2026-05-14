# 0044: Edit Saved Places From the Places List

## Status

Accepted

## Date

2026-05-14

## Context

The Places map flow already lets users create saved places in context and browse saved places without leaving Home. After a place is saved, changing its name or radius, or deleting it, still required going through Settings or had no visible affordance in the Places list.

## Decision

Saved-place rows in the Places list expose explicit row actions for editing and deleting the place. Editing updates the saved place name and radius while keeping the map row selection behavior non-mutating by default. Deleting a saved place reuses the existing Settings deletion path so routine links are cleared consistently.

## Consequences

- Users can manage saved places from the same Places surface where they create and browse them.
- Broad row selection continues to focus the place on the map instead of mutating data.
- Saved-place deletion has one cleanup path across Settings and Places.
