# 0028: Default Places to Check-Ins History

## Status

Accepted

## Date

2026-05-12

## Context

The Places sidebar had a generic "Map detail" label and opened on saved places first. The main review task is usually checking prior place sessions, and the saved-place list is a secondary navigation/check-in surface.

## Decision

The Places sidebar opens on the Check-ins segment by default. The segmented control shows Check-ins before Places, fills the sidebar width, and does not use a separate "Map detail" label. Saved-place rows and check-in rows focus the map on the matching place or coordinate when selected.

## Consequences

- Place history is the first visible review surface.
- Saved places remain available as a secondary segment without an extra section heading.
- Selecting rows in either segment is a map navigation action, while recording a saved-place check-in stays attached to the explicit check-in control.
