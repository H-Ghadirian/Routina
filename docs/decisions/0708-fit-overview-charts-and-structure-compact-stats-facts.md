# 0708: Fit Overview Charts and Structure Compact Stats Facts

## Status

Accepted

## Date

2026-08-31

## Revises

- [0119: Show Cumulative Focus Chart](0119-show-cumulative-focus-chart.md)

## Refines

- [0147: Use Adaptive Stats Dashboard Width](0147-use-adaptive-stats-dashboard-width.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)

## Context

The cumulative Focus chart reused the daily bar chart's very wide, horizontally
scrolling year canvas. When Focus was concentrated near the end of the selected
period, the initial viewport could contain only the earlier zero baseline and
look empty even though the total and detail panel showed data.

The 24-hour rhythm also placed Period, Total, and Strongest hour into three
equal horizontal pills. On a compact iPhone each pill became too narrow, causing
short labels and values to wrap into tall, uneven shapes.

## Decision

- Cumulative Focus is an overview trend and fits its complete selected period
  into the available viewport. It samples a compact set of complete date labels
  and marks the latest cumulative value so data remains visible even for a
  single point or a long ending plateau.
- The daily Focus distribution can retain horizontal detail scrolling where
  the selected range needs it; the cumulative overview does not inherit that
  scrolling behavior.
- The 24-hour rhythm presents Period as one full-width fact and Total plus
  Strongest hour as two structured metric columns inside one summary panel.
  Compact layouts do not force those facts into three equal pills.

## Consequences

- A nonzero cumulative total always has visible chart evidence without requiring
  the person to discover or move a horizontal scroll position.
- Long-range detail and whole-range trend keep distinct, honest presentations.
- Hourly facts remain scannable at compact widths and continue updating with the
  selected hourly metric.
- The change is presentation-only and adds no whole-history derivation to a
  SwiftUI render path.
