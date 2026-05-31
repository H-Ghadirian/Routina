# 0122: Show Focus Achievement Badges

## Status

Accepted

## Date

2026-05-31

## Context

Focus blocks make active focus time visible, but users also benefit from longer-term encouragement that recognizes consistency, depth, and returning after a quiet period. The feature should feel supportive rather than like a punitive scorecard.

## Decision

Stats includes a Focus Achievements section on iOS and macOS. Badges are derived from completed `FocusSession` history and cover all-time focus totals, five-minute blocks, single-session depth, strong focus days, streaks, five focus days in a rolling week, and comeback focus after seven quiet days.

Achievements are presentation-only derived state for now. Routina does not persist unlocked badge rows or celebration state, and the section shows locked badges with progress so users can see the next reachable milestone.

## Consequences

- Focus achievements can be recalculated from existing focus history without a data migration.
- Users see both earned badges and next-progress targets in Stats.
- Future celebration or notification behavior will need separate persisted state if Routina should remember whether a badge has already been announced.
