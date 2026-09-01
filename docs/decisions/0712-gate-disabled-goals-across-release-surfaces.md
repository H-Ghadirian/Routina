# 0712: Gate Disabled Goals Across Release Surfaces

## Status

Accepted

## Date

2026-09-01

## Revises

- [0212: Hide Goal Tab by Default on iOS](0212-hide-goals-tab-by-default.md)
- [0213: Hide Goals UI by Default on macOS](0213-hide-goals-ui-by-default-on-macos.md)
- [0538: Gate Add Task Goals with the Feature Setting](0538-gate-add-task-goals-with-feature-setting.md)
- [0705: Refresh Cross-Platform Development Screenshot Fixtures](0705-refresh-cross-platform-development-screenshot-fixtures.md)

## Refines

- [0227: Gate Stats Goal and Event Reports](0227-gate-stats-goal-event-reports.md)
- [0254: Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md)
- [0470: Keep Beta Experiments Out of Production](0470-keep-beta-experiments-out-of-production.md)

## Context

Goal navigation, creation controls, filters, and Stats reports already followed the
`Show Goals tab` experiment in several places. Preserved Goal links could still
appear in Mac task rows and full Task Details, however, while Settings could still
derive Goal-only Tags or mention Goals in task-data copy. The shared release
screenshot fixture also manufactured Goal records and linked them to fixture tasks.
This advertised a feature that users cannot create or enable in the current release.

## Decision

- `appSettingGoalsTabEnabled` is the cross-platform availability boundary for all
  Goal presentation, navigation, creation, editing, filtering, search metadata,
  task relationship summaries, deep links, Stats reports, and feature-specific
  Settings content.
- While Goals is unavailable, Settings excludes Goal-only Tag rows and counts,
  omits Goals from Tag and task-data copy, does not mutate hidden Goal Tags through
  Tag rename or deletion, and excludes Goal names from the optional AI task
  snapshot. Complete backup, restore, synchronization, and destructive reset still
  preserve and process Goal records as user data.
- Disabling Goals does not delete or rewrite a person's stored Goals or task links.
  Re-enabling the experiment restores those records to available surfaces.
- The development-only Beta Experiments switch remains available in diagnostic
  Settings so developers can re-enable the feature; production does not expose
  that panel.
- The shared release fixture creates no Goal records or task links. Rerunning the
  fixture removes only its three older reserved Goal records and clears Goal links
  from fixture-owned tasks, while preserving unrelated development Goals.

## Consequences

- Release-facing iOS and Mac UI no longer implies that Goal creation is available
  while its toggle is off.
- Hidden Goal data remains compatible with sync, backups, restore, and future
  development re-enablement.
- Release screenshots prepared from the shared fixture cannot accidentally show
  a Goals card or Goal label from fixture-owned data.
