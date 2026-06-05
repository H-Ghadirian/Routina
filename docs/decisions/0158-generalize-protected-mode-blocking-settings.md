# 0158: Generalize Protected Mode Blocking Settings

## Status

Accepted

## Date

2026-06-05

## Context

Routina already supported app and website shielding for iOS Focus and Mac app blocking for Focus, with Away participating in enforcement through the shared shield sync path. Users also expect Sleep to provide the same distraction friction, and separate Focus, Away, and Sleep settings would duplicate the same app and website choices.

The platform capabilities still differ: iOS can use Screen Time tokens for apps, categories, and websites, while the native Mac app can only enforce selected local app bundle identifiers.

## Decision

Blocking uses one Settings section named Blocking. Users manage one distraction list and choose which protected modes use it: Focus, Away, and Sleep.

The enabled protected-mode set is stored as a shared preference. iOS keeps one Screen Time `FamilyActivitySelection` and applies it only while an enabled protected mode is active. macOS keeps selected app bundle identifiers and lets each selected app declare which protected modes it applies to, while the shared enabled-mode set remains a global gate.

Existing Mac app selections migrate to all protected modes so prior Focus selections continue to work and become eligible for Away and Sleep unless users narrow them.

## Consequences

- Focus, Away, and Sleep share a single blocking model instead of separate duplicated settings.
- Sleep mode now syncs the blocker on start, wake, and deletion.
- iOS website blocking remains Screen Time-only; native macOS website blocking remains deferred until a supported entitlement-backed implementation exists.
- Mac app blocking remains best-effort and closes selected apps only when both the active mode and the per-app mode are enabled.
