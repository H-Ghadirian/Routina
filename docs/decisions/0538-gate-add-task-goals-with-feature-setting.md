# 0538: Gate Add Task Goals with the Feature Setting

## Status

Accepted

## Date

2026-08-11

## Supersedes

The Add Task exception in [0212: Hide Goal Tab by Default on iOS](0212-hide-goals-tab-by-default.md). Its default setting and navigation decisions remain active.

## Context

The `Show Goals tab` preference hid Goal navigation and most Goal controls, but the iOS Add Task form still surfaced Goals by default. A disabled feature must not become available through an alternate creation path.

## Decision

`appSettingGoalsTabEnabled` is the availability gate for every Goal control. iOS and macOS Add Task forms omit the Goal section and its progressive-disclosure option while the setting is off. Enabling the setting restores those controls.

## Consequences

- Goal availability is consistent across task creation, navigation, filters, reports, and task details.
- Existing Goal links remain persisted and visible where the feature is enabled; the preference only controls edit/create affordances.
