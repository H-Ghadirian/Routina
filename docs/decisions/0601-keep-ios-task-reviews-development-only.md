# 0601: Keep iOS Task Reviews Development-Only

## Status

Accepted

## Date

2026-08-17

## Revises

The availability portion of
[0540 Group iOS Task Reviews Under More Destination](0540-group-ios-task-reviews-under-more-destination.md).

## Context

The compact iOS `Review tasks` destination combines guided task choice with
focused procedures for filling missing task details. Those flows are useful
for continued evaluation, but they are not intended to appear in release
versions yet. A development-only surface also needs to identify its status
inside the destination so screenshots, testing, and evaluation cannot be
mistaken for production behavior.

## Decision

Compact iOS More shows `Review tasks` only when
`AppEnvironment.isDevelopmentAppVariant` is true. Production and other release
variants do not show the entry or present its destination.

The Review tasks navigation title includes a compact orange `DEV` label. The
existing grouping, child procedures, navigation stack, reducer behavior, and
task-detail routes remain unchanged in development builds.

## Consequences

- Release users do not encounter guided review procedures that are still being
  evaluated.
- Development builds retain one place for exercising the complete task-review
  journey.
- The orange `DEV` label makes the destination's availability explicit without
  relying on color alone.
