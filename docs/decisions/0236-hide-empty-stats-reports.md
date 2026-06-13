# 0236: Hide Empty Stats Reports

## Status

Accepted

## Date

2026-06-13

## Refines

- [0228](0228-place-sleep-stats-with-summary-reports.md)
- [0229](0229-hide-secondary-mac-stats-charts-by-default.md)

## Context

Stats dashboards include reports for many activity types: task outcomes, focus, sleep, away sessions, notes, events, goals, Health movement, and supporting charts. When a user has not used one of those activity types yet, the dashboard could still show a report with a zero value and "no data" copy. That makes first-run and sparse dashboards feel heavier than the user's actual history.

Dashboard customization already treats report availability as a presentation concern, preserving stored order and hidden-item preferences while feature gates or platform gates make reports temporarily unavailable.

## Decision

Stats reports are shown only when their backing metric has data. For example, Sleep time is hidden while total sleep duration is zero, Sleep sessions is hidden until at least one sleep session exists, and count-based reports are hidden until their count is nonzero.

This reportability rule applies to summary cards and dashboard sections on iOS and macOS. It does not delete stored dashboard ordering or hidden-item preferences; unavailable reports can reappear in the user's existing order when matching activity exists later.

## Consequences

- Empty Stats dashboards avoid zero-value reports for activity types the user has not used yet.
- Sleep, Away, Focus, Health, Goal, Event, Emotion, Note, task outcome, and chart reports become visible as soon as their corresponding metrics become nonzero.
- No migration is needed because report availability is derived from the current metrics at presentation time.
