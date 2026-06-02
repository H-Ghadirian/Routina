# 0134: Add Personal Record Achievement Domains

## Status

Accepted

## Date

2026-06-02

## Context

Stats achievements now cover focus, sleep, away, and done history. Routina also records emotions, places, goals, and notes as first-class personal records, so leaving those histories out makes the Achievements view underrepresent how users build a fuller routine system.

## Decision

Achievements include Emotions, Places, Goals, and Notes categories alongside the existing All, Focus, Sleep, Away, and Done categories.

These new badges remain derived all-time presentation state. Emotion badges use `EmotionLog` totals, unique days, streaks, emotion family coverage, reflections, and context links. Place badges use saved `RoutinePlace` rows and finished `PlaceCheckInSession` history. Goal badges use total goals, active goals, target dates, tags, sub-goals, and archived goals. Note badges use note totals, tagged notes, media-bearing notes, voice notes, and note creation consistency.

## Consequences

- Achievement progress now reflects Routina's broader personal record model without adding migrations or persisted unlock rows.
- Place achievement data must be available to Stats on both iOS and macOS, including saved places and finished check-in sessions.
- Future achievement additions should continue to favor milestones that can be recalculated from existing model history.
