# 0146: Tab Achievement Status and Achieved Periods

## Status

Accepted

## Date

2026-06-03

## Supersedes

[0132](superseded/0132-categorize-achievement-badges.md)

## Context

[0132](superseded/0132-categorize-achievement-badges.md) separated achievement badges into In Progress and Achieved groups inside one Achievements view. As the badge list grew, showing both groups together made the section long and made recent unlocks harder to inspect. Users also want to look at badges achieved during familiar periods such as today, this week, this month, and this year.

## Decision

The Achievements section keeps the domain category picker, then shows In Progress and Achieved as separate status tabs. The In Progress tab shows locked badges for the selected domain. The Achieved tab shows a second period picker with Today, This Week, This Month, and This Year.

Because badge unlock rows are not persisted, period achieved lists are derived by comparing the current all-time achievement set with the same achievement set recalculated from history before the selected period began. A badge appears in a period when it is earned now and was not earned before that period.

## Consequences

- Users can switch between future targets and recent earned badges without scrolling through both groups.
- Achieved period filters remain presentation-only and require no badge persistence migration.
- Period filters are a derived approximation for stateful badges whose historical state changes are not separately timestamped.
