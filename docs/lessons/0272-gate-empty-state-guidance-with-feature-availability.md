# 0272 — Gate empty-state guidance with feature availability

Date: 2026-08-30

## Symptom

The Stats empty state told a person that reports would appear after they logged
Sleep even when Sleep was disabled, making an unavailable activity look usable.

## Root Cause

Stats gated Sleep scopes, actions, filters, and reports, but its shared empty-state
sentence was static. The presentation received filter state only, so neither the
iOS nor Mac caller could make the guidance follow effective Sleep availability.

## Fix

The shared empty-state presentation now receives effective Sleep availability,
defined by both the Away parent gate and the Sleep experiment gate. It omits
Sleep from unfiltered guidance when either setting is off while preserving the
existing filter-recovery message.

## Prevention Rule

Treat instructional and empty-state copy as a feature presentation boundary.
Any named optional capability must be derived from the same effective
availability gates as its actions and navigation, including parent gates.

## Regression Safeguard

The Empty Stats Guidance scenario covers enabled, disabled, and filtered states.
`StatsEmptyDashboardMessageTests` verifies the exact shared copy and confirms
that both platform Stats views pass the combined Away-and-Sleep availability.

Related decisions: [0221 — Hide Stats Sleep Tab Behind Beta Toggle](../decisions/0221-hide-stats-sleep-tab-behind-beta-toggle.md) and [0279 — Hide Sleep Stats and Blocking With Away Toggle](../decisions/0279-hide-sleep-stats-and-blocking-with-away-toggle.md).
