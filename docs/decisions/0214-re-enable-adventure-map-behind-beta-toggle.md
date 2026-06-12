# 0214: Re-enable Adventure Map Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Refines

- [0161](0161-hide-mac-adventure-for-release-stabilization.md)

## Context

Adventure visibility was intentionally disabled in release-facing surfaces while core implementation remains in the codebase. We now want to keep that implementation present but allow user opt-in testing from Settings, aligned with how Goals and Git features are gated today.

## Decision

Mac Home reintroduces the Adventure map as a beta option only when `appSettingAdventureMapEnabled` is enabled from settings. Home sidebar modes and progress mode controls continue to default to Stats when disabled so users are not exposed to unfinished surfaces unless explicitly enabled.

## Consequences

- Adds an `appSettingAdventureMapEnabled` user-default flag and registers its default as `false`.
- Adds an Adventure map toggle in Settings (Mac and iOS under General → Advanced/Beta Experiments).
- Keeps compatibility fallbacks so stored `.adventure` mode values resolve to Stats when disabled.
