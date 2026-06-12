# 0216: Move Mac Home Task Type Tabs to Filter Screen

## Status

Accepted

## Date

2026-06-12

## Context

Mac Home exposes `All`, `Todos`, and `Routines` as a task type switch in the left sidebar for the primary Tasks tab. That switch competes with the main sidebar navigation even though it behaves like a task-list filter, and most users should start from the combined list.

## Decision

Mac Home now defaults the task list mode to `All`. The `All`, `Todos`, and `Routines` selector lives in the Home filter detail screen by default. The old sidebar selector remains available only when `appSettingHomeTaskListModeTabsVisible` is enabled from Settings (Mac -> General -> Beta Experiments).

## Consequences

- New and reset Mac Home state starts from the combined task list.
- Sidebar chrome is quieter by default, while the task type choice remains discoverable in filters.
- Users who prefer the previous sidebar tabs can opt back in from Settings.
- The existing preference key remains a local `UserDefaults` beta preference and is not promoted to durable SwiftData preferences.
