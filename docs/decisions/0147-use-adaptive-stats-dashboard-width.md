# 0147: Use Adaptive Stats Dashboard Width

## Status

Accepted

## Date

2026-06-03

## Context

Stats dashboard sections are card and chart grids that can adapt to available space. The iOS regular-width and macOS Stats views still capped the main dashboard column at 980 points, then centered it inside the detail pane. On wide Mac windows and large iPad layouts, this left large unused areas while achievement and recent-win cards stacked vertically and required extra scrolling.

## Decision

Stats dashboard content uses the available detail-column width on iOS and macOS instead of applying a fixed regular-width maximum. Dashboard cards, achievements, and recent wins continue to use adaptive grids so additional horizontal space becomes additional columns rather than oversized fixed cards.

If a future Stats section needs a readable text measure, that section should constrain its own text or control width locally instead of narrowing the entire dashboard.

## Consequences

- Wide windows show more Stats cards per row and reduce unnecessary vertical scrolling.
- The Stats dashboard aligns with the leading edge of its detail pane instead of centering a narrow column in unused space.
- Compact layouts keep their existing behavior because they already used the available width.
