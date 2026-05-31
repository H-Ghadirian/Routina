# 0113: Allow Stats Dashboard Reordering

## Status

Accepted

## Date

2026-05-31

## Context

Stats already supports hiding and restoring dashboard items, but the visible order has been fixed by code. Users need to shape the dashboard around the sections they check most often.

## Decision

Stats dashboard edit mode supports dragging visible dashboard sections to reorder them on iOS and macOS. The item order is stored as synced string settings separate from the existing hidden-item settings, and reset clears both hidden items and custom ordering.

The top range/filter controls stay fixed above the dashboard; dashboard cards and chart sections participate in the stored order.

## Consequences

- Users can personalize the Stats screen without changing task or activity data.
- New dashboard items append to the default order if they are missing from an older stored order.
- Hidden items keep their place in the stored ordering and reappear in that place when added back.
