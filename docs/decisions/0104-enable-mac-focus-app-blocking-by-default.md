# 0104: Enable Mac Focus App Blocking by Default

## Status

Accepted

## Date

2026-05-30

## Context

Mac focus app blocking is most useful when it activates automatically during a running focus timer. Requiring users to remember a second enable switch after selecting blocked apps makes the feature easy to misconfigure.

Users still need control over whether blocking is active and which apps are included.

## Decision

The Mac focus app blocker defaults to enabled. With the default setting, selected blocked apps are enforced whenever a task focus timer is running. Users can still disable the blocker with the Focus card toggle, and they can change or clear the app list at any time.

An explicit disabled preference remains authoritative so users who turn app blocking off do not have it re-enabled by future launches.

## Consequences

- Choosing apps is enough for blocking to apply during future task focus timers.
- Existing explicit user-off preferences continue to disable Mac app blocking.
- An empty blocked-app list remains harmless even though the blocker preference defaults to enabled.
