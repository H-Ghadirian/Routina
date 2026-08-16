# 0187 — Make chart overflow fill its viewport

Date: 2026-08-16

## Symptom

Focus-chart day labels truncated into ellipses on iPhone. On a wide Mac Stats
window, both focus plots remained roughly phone-width and sat against the trailing
edge while most of their cards were empty.

## Root Cause

The day axis independently labeled every active focus day in addition to its
range ticks, so label density grew with the data. When horizontal overflow was
enabled, the chart received only a minimum width and no viewport-relative width;
its trailing scroll anchor therefore positioned that minimum-width plot at the
far side of a much wider Mac card.

## Fix

Both focus charts now sample one shared day-axis strategy that preserves range
anchors, limits longer compact ranges to five ticks, and uses short day labels
after the first visible month label. Scrollable focus plots first take the full
horizontal viewport and only grow beyond it when their range requires overflow.

## Prevention Rule

Chart axes must bound label count by presentation width rather than the number of
nonzero data points. Content inside a horizontal chart scroller must fill the
scroller viewport before applying its data-driven minimum width.

## Regression Safeguard

`StatsFeatureDerivedStateSupportTests` verifies compact and regular label limits,
first/last range anchors, short custom-range labels, removal of the active-day
axis overlay, and viewport-relative sizing in the shared focus-chart container.

Related decisions: [0119 — Show Cumulative Focus Chart](../decisions/0119-show-cumulative-focus-chart.md) and [0147 — Use Adaptive Stats Dashboard Width](../decisions/0147-use-adaptive-stats-dashboard-width.md).
