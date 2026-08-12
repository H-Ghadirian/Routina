# 0552: Keep iOS Saved-Tag Settings Compact

## Status

Accepted

## Date

2026-08-12

## Context

iOS Settings -> Tags repeated fast-filter, overflow, color, and optional
related-tag controls for every saved tag. As a catalog grows, the controls
obscure the tag names and usage summaries that people need to scan first.

## Decision

Each saved-tag row on iOS initially shows only its tag pill, usage summary,
and a disclosure affordance. Selecting the full summary row reveals the
existing fast-filter, rename/delete, color, and optional related-tag controls
for that tag only. Selecting another tag moves the expanded controls to that
row; selecting the expanded row again collapses it.

The selection is local, temporary view state. It is not saved, restored, or
allowed to change tag metadata, filtering, or the existing swipe actions.

## Consequences

- Dense tag catalogs remain easy to scan.
- Every existing setting remains available after one deliberate selection.
- The complete selected summary row is an accessible, 44-point-tall tap
  target rather than relying on the tag pill or a small disclosure icon.
