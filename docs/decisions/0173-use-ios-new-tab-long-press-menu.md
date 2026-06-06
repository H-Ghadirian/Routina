# 0173: Use iOS New Tab Long-Press Menu

## Status

Accepted

## Date

2026-06-07

Supersedes part of [0071](0071-move-ios-task-add-to-tab-bar.md) and [0073](0073-open-ios-home-actions-horizontally.md) for compact iOS capture actions.

## Context

The compact iOS bottom bar had a `Task` plus action for smart task creation, while Home kept separate toolbar actions for note, check-in, sleep, emotion, away, and event capture. Long-pressing the Home tab also owned a small Home menu, which made creation and mode entry feel tied to Home instead of available as global app actions.

As capture surfaces grew beyond tasks, the bottom bar needed a broader affordance that could still preserve one-tap task entry.

## Decision

The iOS bottom-bar task action is labeled `New`. Tapping it still opens the unified smart task add flow.

Long-pressing the `New` tab opens a menu above that tab with Event, Emotion, Note, Goal, Task, Check In, Away, and Going to sleep. Goal creation routes through the Goals flow, task creation routes through Home's smart add flow, and standalone event, emotion, note, check-in, away, and sleep actions use their existing creation or start presentations.

Home keeps Home-specific controls such as filters, but no longer owns the general new-action menu or duplicated compact creation/start actions.

## Consequences

- Compact iOS has one global new-action affordance in the bottom bar while preserving fast task capture on tap.
- Home is less crowded and no longer acts as the owner of capture actions that are useful from any tab.
- The existing sleep menu setting is reused for the `New` menu sleep item for compatibility with stored user preferences.
