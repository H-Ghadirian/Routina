# 0079: Use Segmented Mood Input for Emotions

## Status

Accepted

## Date

2026-05-27

## Context

Emotion logs store a pleasantness and energy position. The original editor exposed those values through a two-axis mood map, but the map required users to interpret a chart before logging how they feel.

## Decision

The emotion editor uses two segmented pickers for mood input: Pleasantness and Energy. Each picker maps to the existing stored pleasantness/energy values, so the data model and timeline behavior remain unchanged.

The emotion detail view may still visualize saved values, but capture should prioritize quick, plain-language selection over chart manipulation.

## Consequences

- Emotion capture is faster and easier to understand.
- The stored `EmotionLog` affect values remain compatible with existing backup, import, timeline, and detail surfaces.
- Future emotion capture UI should keep the input language explicit instead of requiring users to infer axes from a chart.
