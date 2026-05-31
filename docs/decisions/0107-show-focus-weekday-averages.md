# 0107: Show Focus Weekday Averages

## Status

Accepted

## Date

2026-05-31

## Context

Routina already charts total focus duration per day for the selected Stats range. Week and month review also need a weekday rhythm view so the user can see whether focus time tends to cluster on particular days of the week.

## Decision

Stats shows a weekday-average focus chart for week and month ranges. The weekday averages are derived from the same daily focus duration series as the main focus chart, so selected filters, unassigned focus sessions, calendar time zones, and zero-focus days are handled consistently.

The average for a weekday is total focus duration on matching days divided by the number of matching calendar days in the selected range, including days with no focus time.

## Consequences

- Week range weekday averages mirror the seven daily totals while preserving weekday ordering.
- Month range weekday averages show typical focus duration for Mondays, Tuesdays, and the other weekdays across the trailing 30 days.
- Focus stats keep using one shared derived data path for iPhone and Mac.
