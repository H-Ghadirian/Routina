# 0415: Support Custom Stats Date Ranges

Status: Accepted

## Context

Stats previously offered only Today and trailing 7-, 30-, and 365-day windows, all ending on the current day. Reviewing activity around a project, trip, season, or other personally meaningful interval required an arbitrary inclusive start and end date.

## Decision

Keep Today, Week, Month, and Year as quick presets and add a Custom range to iOS and macOS Stats. A custom range stores normalized inclusive start and end days, is persisted with temporary Stats view state, and becomes the shared boundary for every available dashboard metric and integration.

The custom range UI prevents the start from moving after the end and the end from moving before the start. Charts adapt their sampling and scrolling to the custom range's length.

## Consequences

- Users can review Stats for any calendar-day interval.
- Existing persisted preset values remain decoding-compatible.
- Health and Git contribution requests use the same custom boundaries as local activity, focus, task, and report calculations.
