# 0254: Move Mac Task Row Appearance to Home Filter Detail

## Status

Accepted

## Date

2026-06-19

## Context

Mac task row visibility controls were under `Settings > Appearance > Task Row`.
Those controls shape the Home task list itself, and users often adjust row density
while tuning the same list's filters, grouping, and sort order.

The Home filter detail screen already owns Mac task-list filtering controls after
[0216](0216-move-mac-home-task-type-tabs-to-filter-screen.md). Keeping row
appearance beside Filter and Sort makes the task-list customization surface more
local without changing the underlying persisted preference.

## Decision

Mac Home filter detail now has `Filter`, `Sort`, and `Appearance` tabs. The
`Appearance` tab owns Task Row field visibility for the Mac Home task list.
Because macOS Goal surfaces are gated by `appSettingGoalsTabEnabled`, the
Task Row `Goals` visibility control is shown only while Goals are enabled.

The setting continues to use the existing `appSettingHomeTaskRowHiddenFields`
preference and the existing Settings appearance mutation path. No data migration
is needed.

`Settings > Appearance` on macOS no longer shows the `Task Row` card.

## Consequences

- Mac task-list filtering, sorting, and row appearance now live in one task-list
  customization surface.
- Existing task row visibility choices keep working because storage is unchanged.
- Settings diagnostics, backup/import preference mirroring, and iOS task-row
  appearance controls keep using the same shared preference.
