# 0086: Show All-Day Calendar Events in the Planner

## Status

Superseded by [0090](0090-support-manual-all-day-tasks.md)

## Date

2026-05-27

## Context

Outlook and Apple Calendar can contain all-day events such as sickness, travel, holidays, or vacation. Routina's calendar import already captured whether a suggestion was all-day, but adding it as a task flattened that event into a one-off deadline. The planner only had timed blocks, so all-day events either disappeared from planner context or looked like ordinary tasks.

## Decision

Imported all-day calendar events render in a dedicated all-day lane above the planner's timed grid. The lane can show single-day and multi-day spans across the visible week, and tapping an all-day event opens the related task detail flow.

Calendar imports preserve all-day start and end dates as internal calendar metadata in the task notes alongside the existing source marker. These metadata lines stay hidden from user-visible notes and are preserved when the visible notes are edited. Existing imported calendar tasks without metadata are treated as one-day all-day events when they have a date-only one-off deadline and a calendar source marker.

## Consequences

- Sickness, travel, vacation, and similar all-day calendar items stay visible without occupying a timed hour slot.
- Multi-day all-day imports can span multiple planner columns.
- Legacy date-only calendar imports still get a useful one-day all-day representation, but they cannot recover an original multi-day span unless reimported with metadata.
- A future dedicated external-event model can replace the notes metadata without changing the planner lane behavior.
