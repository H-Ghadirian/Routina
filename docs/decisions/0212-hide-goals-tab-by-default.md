# 0212: Hide Goal Tab by Default on iOS

## Status

Accepted

## Date

2026-06-12

## Context

Users reported that iOS navigation should focus on home, search, and essentials without the Goals tab being visible by default. At the same time, they still need a path to add goals and manage them while composing tasks, and a user-level setting to make the Goal tab visible when they want.

## Decision

- Add a persisted app setting key `appSettingGoalsTabEnabled` with default `false` in `SharedDefaults`.
- Hide the standard iOS Goal tab unless `appSettingGoalsTabEnabled` is enabled.
- In compact iOS More navigation, include the Goal destination and row only when `appSettingGoalsTabEnabled` is enabled.
- Ensure Add-task compact form defaults include the Goal section during create flow.
- Expose a toggle in Settings → General to opt in to showing the Goal tab.

## Consequences

- Default iOS startup behavior no longer shows Goals in the main tab bar.
- Goals remain available through task creation flow and the underlying feature state continues to function.
- Users can explicitly enable the Goal tab later from Settings.
