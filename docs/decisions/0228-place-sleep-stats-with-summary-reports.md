# 0228: Place Sleep Stats With Summary Reports

## Status

Accepted

## Date

2026-06-13

## Refines

- [0221](0221-hide-stats-sleep-tab-behind-beta-toggle.md)

## Context

Sleep time and Sleep sessions use the same compact summary-card treatment as the other factual Stats reports. If a user has saved dashboard ordering from before Sleep cards were present or available, newly available Sleep cards can be appended after chart sections, visually separating them from reports that look and behave the same.

## Decision

Default dashboard order normalization should insert newly available default reports near their default neighbors instead of always appending them at the end. Sleep time and Sleep sessions therefore land beside the other summary cards by default, while existing user ordering for already-known items remains intact.

Users can still move or hide Sleep cards through the dashboard customization controls.

## Consequences

- Sleep summary cards stay visually grouped with comparable Stats reports by default.
- Saved custom dashboard orders remain respected, with only missing default items placed into their intended neighborhood.
- No data migration is needed because the stored order string is normalized at presentation time.
