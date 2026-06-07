# 0173: Use iOS New Tab Sheet

## Status

Accepted

## Date

2026-06-07

Supersedes part of [0071](0071-move-ios-task-add-to-tab-bar.md) and [0073](0073-open-ios-home-actions-horizontally.md) for compact iOS capture actions.

## Context

The compact iOS bottom bar had a `Task` plus action for smart task creation, while Home kept separate toolbar actions for note, check-in, sleep, emotion, away, and event capture. Home also owned a small tab menu, which made creation and mode entry feel tied to Home instead of available as global app actions.

As capture surfaces grew beyond tasks, the bottom bar needed a broader affordance that could present all new actions without requiring a hidden gesture or taking over the screen.

## Decision

The iOS bottom-bar task action is labeled `New`.

Tapping the `New` tab opens a compact, non-full-screen action sheet with Event, Emotion, Note, Goal, Task, Check In, Away, and Going to sleep. Goal creation routes through the Goals flow, task creation routes through Home's smart add flow, and standalone event, emotion, note, check-in, away, and sleep actions use their existing creation or start presentations.

Home keeps Home-specific controls such as filters, but no longer owns the general new-action menu or duplicated compact creation/start actions.

## Consequences

- Compact iOS has one global new-action affordance in the bottom bar without relying on a long-press discovery gesture.
- Home is less crowded and no longer acts as the owner of capture actions that are useful from any tab.
- The existing sleep menu setting is reused for the `New` sheet sleep item for compatibility with stored user preferences.
