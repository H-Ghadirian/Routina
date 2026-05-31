# 0114: Clarify Emotion Trend Chart

## Status

Accepted

## Date

2026-05-31

## Context

The Emotion Trends chart plotted daily average pleasantness and energy, but its visible framing emphasized peak intensity and did not make the two drawn lines obvious enough.

## Decision

The chart is labeled as Pleasantness & Energy, shows a visible color legend, and displays the shared -1 to +1 scale in the header. Intensity remains factual supporting context instead of the primary chart badge because intensity is not one of the plotted lines.

## Consequences

- Users can tell that pink represents pleasantness and teal represents energy without relying on chart internals.
- The chart remains based on stored daily averages.
- Intensity stays available as supporting context without competing with the plotted measures.
