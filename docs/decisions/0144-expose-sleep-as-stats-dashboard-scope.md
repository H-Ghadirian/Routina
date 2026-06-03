# 0144: Expose Sleep as a Stats Dashboard Scope

## Status

Accepted

## Date

2026-06-03

## Context

Routina already models sleep as first-class app-level session data and includes sleep milestones in Achievements. The main Stats dashboard scope picker still only offered All, Focus, and Achievements, which made sleep harder to inspect without scanning the full dashboard or entering the achievements category picker.

## Decision

Stats includes a top-level Sleep dashboard scope on iOS and macOS. The Sleep scope shows range-bound sleep summary cards, including total sleep time and sleep session count, derived from `SleepSession` history. Active sleep sessions contribute duration up to the current reference date, matching the way active protected sessions can remain visible in stats.

Achievements remains its own dashboard scope; sleep achievements stay available through the Achievements section category picker instead of being mixed into the Sleep dashboard scope.

## Consequences

- Users can jump directly to sleep stats from the main Stats category picker.
- Sleep dashboard cards are recalculated from existing `SleepSession` rows and do not require persisted stats or migrations.
- Future sleep-specific charts or trends should live under the Sleep scope when they summarize sleep behavior rather than general activity.
