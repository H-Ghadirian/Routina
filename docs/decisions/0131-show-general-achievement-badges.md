# 0131: Show General Achievement Badges

## Status

Accepted

## Date

2026-06-02

## Supersedes

[0122](superseded/0122-show-focus-achievement-badges.md)

## Context

Stats achievement badges started as a focus-only section. Routina now has first-class sleep sessions, away sessions, and richer done history, so keeping achievements tied only to focus makes the app's encouragement feel narrower than the activity it records.

## Decision

Stats includes a general Achievements dashboard section on iOS and macOS. The dashboard scope picker includes an Achievements segment that shows this section, while the existing focus dashboard scope stays limited to focus-specific stats.

Achievements remain presentation-only derived state. The section preserves the focus badges from [0122](superseded/0122-show-focus-achievement-badges.md) and adds badges derived from completed sleep sessions, finished Away sessions, planned-duration Away completions, and completed `RoutineLog` history.

Locked badges remain visible with progress so users can see reachable milestones. Routina still does not persist unlocked badge rows or celebration state.

## Consequences

- Achievement progress can be recalculated from existing focus, sleep, away, and done history without a data migration.
- Sleep and Away badges use their dedicated session models instead of treating those periods as focus or routine completions.
- Future celebration or notification behavior still needs separate persisted state if Routina should remember whether a badge has already been announced.
