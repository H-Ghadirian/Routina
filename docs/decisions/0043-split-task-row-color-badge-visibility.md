# 0043: Split Task Row Color Badge Visibility

## Status

Accepted

## Date

2026-05-14

## Context

Settings > Appearance > Task Row used one Row Color toggle for both the custom task tint/background and the small row-edge color marker. Users may want calmer row surfaces while still keeping the compact color marker, or keep tinted rows without the marker.

## Decision

Routina treats the row color tint/background and the color badge as separate task-row fields. Row Color controls the task-specific row surface tint/background. Color Badge controls the small row-edge custom color marker.

This supersedes the part of [0038](0038-configure-home-task-row-fields.md) that grouped the row tint and row color marker under one visibility field.

## Consequences

- Existing rows still show both by default because hidden fields remain opt-out.
- Hiding Row Color no longer hides the color badge.
- Hiding Color Badge does not remove the row tint/background or the saved task color.
