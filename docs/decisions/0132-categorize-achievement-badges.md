# 0132: Categorize Achievement Badges

## Status

Superseded

## Superseded By

[0146](0146-tab-achievement-status-and-periods.md)

## Date

2026-06-02

## Context

[0131](0131-show-general-achievement-badges.md) broadened Stats achievements beyond focus. A single mixed badge grid makes it harder to scan progress once focus, sleep, away, and done milestones live together.

## Decision

The Stats Achievements section can be viewed by category: All, Focus, Sleep, Away, and Done. Within the selected category, badges are separated into In Progress and Achieved groups, with in-progress badges shown first.

The category and status grouping remains presentation state only. Badge unlocks continue to be derived from existing activity history without persisted achievement rows.

## Consequences

- Users can scan the achievement domain they care about without hiding locked progress targets.
- Achieved badges are visually and structurally separate from still-in-progress badges.
- New achievement badge domains should be added to the category picker when they represent a meaningful user-facing activity area.
