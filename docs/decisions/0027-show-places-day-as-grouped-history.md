# 0027: Show Places Day as Grouped History

## Status

Accepted

## Date

2026-05-12

## Context

The Places Day tab previously focused on one selected date at a time. That made older check-ins require manual day-by-day navigation and made the tab behave differently from the app's main timeline, where history is scanned as one reverse-chronological list grouped by day.

## Decision

The Places Day tab shows all place check-in sessions in one grouped history list. Section headers use the same day-title wording as the main timeline, including Today and Yesterday, and sessions are ordered newest-first within newest-first day sections.

## Consequences

- Users can review all prior place check-ins without paging through individual dates.
- Places Day and the main timeline use matching day grouping language.
- Per-day duration summaries are no longer the primary navigation surface for Places history.
