# 0217: Hide Board Screen Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Context

The Mac Board surface remains implemented, but it should not be part of the default Home workspace while the app stabilizes its primary task and planner flows. Routina already uses Settings-based beta switches for other optional surfaces such as Goals, Adventure, and Mac website blocking, so Board should follow the same explicit opt-in pattern.

## Decision

Mac Home hides the Board detail mode by default. Users can enable it from Settings -> General -> Beta Experiments with the `appSettingBoardScreenEnabled` flag.

Stored or deep-linked attempts to show Board resolve to Details while the flag is disabled, preserving the underlying board data and routes without exposing the screen by default.

## Consequences

- Adds an `appSettingBoardScreenEnabled` user-default flag and registers its default as `false`.
- Adds a Board screen toggle in Mac Settings -> General -> Beta Experiments.
- Keeps Board implementation and state intact for users who opt in.
- Keeps compatibility fallbacks so stale Board detail-mode state resolves to Details while disabled.
