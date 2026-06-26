# 0279: Hide Sleep Stats and Blocking With Away Toggle

- Status: Accepted
- Date: 2026-06-26
- Refines: [0012 Model Sleep as an App-Level Session Mode](0012-model-sleep-as-app-level-session-mode.md), [0158 Generalize Protected Mode Blocking Settings](0158-generalize-protected-mode-blocking-settings.md), [0221 Hide Stats Sleep Tab Behind Beta Toggle](0221-hide-stats-sleep-tab-behind-beta-toggle.md), [0228 Place Sleep Stats With Summary Reports](0228-place-sleep-stats-with-summary-reports.md), and [0277 Hide Notes and Away Behind Beta Toggles](0277-hide-notes-and-away-behind-beta-toggles.md)

## Context

Sleep remains a separate protected-session model, but its user-facing entry points have been grouped with Away because both represent protected time away from the screen. After Away became hidden by default, Stats and Blocking could still expose Sleep cards, scopes, achievements, wins, and mode controls. That made fresh installs show Sleep-specific information even though the umbrella Away experiment was off.

## Decision

When Support & About -> Beta Experiments -> `Show Away` is off, Stats must not present Sleep-specific dashboard cards, the Sleep dashboard scope, Sleep achievement or win contributions, Adventure Sleep reward copy, or the `Show Sleep tab` beta toggle. Stats and Adventure data feeds should pass empty Sleep session collections while Away is hidden so existing Sleep history is preserved but not reportable in those surfaces.

Settings -> Blocking must also omit Sleep mode controls while Away is off. The visible Blocking mode list is Focus-only when Away is hidden, and per-app or per-website mode checkboxes omit both Away and Sleep. Stored blocking-mode preferences can still retain Sleep for compatibility and reappear when Away is enabled.

## Consequences

- Fresh installs do not show Sleep information in Stats, Adventure, or Blocking while the Away experiment is off.
- Existing `SleepSession` records, backup/import behavior, deep links, and protection compatibility remain intact.
- Users who enable Away can still opt into the Sleep Stats scope with the existing `appSettingStatsSleepTabEnabled` setting.
