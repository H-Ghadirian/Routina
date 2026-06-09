# 0193: Clarify Stats Activity Rhythm Preview

## Status

Accepted

## Date

2026-06-09

## Context

The Stats hero preview was labeled `Daily rhythm` for every time range. That worked passably for week, but month and year views sampled a small number of individual days and stretched them across the card. In year view, especially for newer data where the range starts at the first recorded activity, a few unlabeled day bars looked like arbitrary large blocks and did not explain the year pattern.

## Decision

The Stats hero preview is a range-level activity preview, not always a daily chart. Week shows daily buckets, month groups the selected days into roughly week-sized buckets, and year shows a trailing 12-month frame with one bucket per calendar month. The preview title names the bucket scale, each bucket shows a short date/month label, and the caption names the best day explicitly.

The detailed timeline activity chart remains the place for per-day outcome details across the selected range.

## Consequences

- Year view reads as a year-shaped month strip instead of a few sampled days or one oversized active-month block.
- Month view becomes easier to scan at a glance without hiding the detailed daily chart.
- Sparse year ranges no longer stretch one or two recent activity days into full-width shapes without labels.
