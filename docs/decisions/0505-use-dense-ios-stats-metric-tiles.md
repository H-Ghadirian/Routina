# 0505: Use Dense iOS Stats Metric Tiles

## Status

Accepted

## Date

2026-08-08

## Refines

- [0115](0115-support-compact-stats-summary-cards.md)

## Context

The original iOS Cards mode uses large, vertically spacious summary cards.
With several metrics available, especially Health metrics, those cards consume
substantial vertical space without improving scanning. The separate Compact
mode is useful for row-oriented review but gives up the fast two-column metric
scan.

## Decision

iOS Cards mode uses dense two-column metric tiles. Each tile has a compact
icon and title header, a single-line value, and an optional single-line
caption. The tile has a smaller minimum height, padding, and corner radius
than the former spacious card.

The iOS Compact mode remains the existing one-column summary-row
presentation. macOS keeps the existing spacious card presentation. Dashboard
metrics, ordering, visibility, colors, accessories, and preferences are
unchanged.

## Consequences

- iOS shows substantially more summary metrics per screen while retaining the
  two-column visual scan.
- Long values and captions scale within their tile instead of expanding the
  grid vertically.
- The shared card component exposes an explicit iOS dense-tile presentation
  without changing the macOS dashboard.
