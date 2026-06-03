# 0141: Show Achievement Period Celebrations

## Status

Superseded

## Superseded By

[0145](../0145-separate-recent-wins-from-achievements.md)

## Date

2026-06-03

## Context

The Achievements dashboard already shows all-time badge progress, including locked milestones. That is useful for long-range motivation, but it does not quickly answer what the user accomplished recently. Users also want Achievements to feel celebratory instead of only aspirational.

## Decision

The Achievements section shows a Recent Wins area before the all-time badge groups. It summarizes accomplishments for Today, This Week, This Month, and This Year using the current calendar and only renders period cards that have at least one recorded accomplishment.

Recent Wins counts completed tasks, completed focus time, completed sleep time, finished Away time, emotion logs, notes, created goals, saved places, and finished place check-ins. The all-time achievement badges remain unchanged and continue to show locked and achieved milestone progress by category.

## Consequences

- The Achievements section can celebrate recent activity without diluting long-term badge progress.
- Empty periods stay hidden so the section does not create discouraging blank states.
- Period summaries are derived from existing history and require no new persistence.
