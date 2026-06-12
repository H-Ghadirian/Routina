# 0222: Configure Timeline Row Fields

## Status

Accepted

## Date

2026-06-12

## Context

Task row fields are already configurable from `Settings > Appearance` so users can hide row elements that are not useful for their workflow.
Timeline rows now include additional density-sensitive pieces (icon, row position in list contexts, subtitle, type badge) and should be similarly controllable to keep the timeline interface readable on different screen sizes and use cases.

## Decision

Routina adds a new configurable timeline row visibility setting in `Settings > Appearance` under a dedicated `Timeline Row` section.

The setting stores hidden timeline fields in a shared preference key as a comma-separated list of hidden fields (`appSettingHomeTimelineRowHiddenFields`).

Routina applies the visibility setting when rendering timeline rows in:
- Home timeline sidebar rows (macOS)
- Timeline tab rows (iOS and macOS)

## Consequences

- Timeline row appearance can be customized alongside task row customization.
- All available timeline row fields default to visible until users explicitly hide them.
- The setting is persisted via shared defaults and mirrored into settings diagnostics snapshots so it stays in sync with existing settings flows.
