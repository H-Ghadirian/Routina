# 0324: Hide Mac Stats Dashboard Controls Behind Beta Toggle

## Status

Accepted

## Date

2026-07-01

## Refines

- [0113](0113-allow-stats-dashboard-reordering.md)
- [0115](0115-support-compact-stats-summary-cards.md)
- [0229](0229-hide-secondary-mac-stats-charts-by-default.md)

## Context

The Mac Stats toolbar exposes dashboard customization through the Summary view menu and Edit button. Those controls are useful for users actively tuning their dashboard, but they add persistent toolbar chrome to a screen that is usually read-only.

Routina already keeps advanced or dense Mac surfaces behind Support & About -> Beta Experiments while preserving the stored preferences underneath.

## Decision

Mac Stats hides the Summary view menu and Edit button by default. Users can enable them from Support & About -> Beta Experiments -> `Show Stats dashboard controls`, backed by `appSettingMacStatsDashboardControlsEnabled`.

When the toggle is off, saved summary density, dashboard item order, and hidden-item preferences remain intact. If the toggle is turned off while Stats editing is active, the Stats view exits editing and dismisses the Add-to-Stats sheet.

## Consequences

- The default Mac Stats toolbar stays quieter for regular dashboard reading.
- Dashboard customization remains available as an explicit beta experiment.
- Existing dashboard customization state is preserved while the toolbar controls are hidden.
