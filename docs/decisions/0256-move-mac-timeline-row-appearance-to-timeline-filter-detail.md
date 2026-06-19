# 0256: Move Mac Timeline Row Appearance to Timeline Filter Detail

## Status

Accepted

## Date

2026-06-19

## Context

Timeline row visibility controls were under `Settings > Appearance > Timeline Row`.
Those controls shape the Home Timeline list directly, and users often adjust row
density while tuning timeline filters such as range, type, media, importance, and
tags.

Task row appearance had already moved into the Home task filter detail in
[0254](0254-move-mac-task-row-appearance-to-home-filter-detail.md). Keeping
Timeline row appearance beside Timeline filters gives the timeline surface the
same local customization model without changing the stored preference.

## Decision

Mac Home timeline filter detail now has `Filter` and `Appearance` tabs. The
`Appearance` tab owns Timeline Row field visibility for the Mac Home timeline
list.

The setting continues to use the existing
`appSettingHomeTimelineRowHiddenFields` preference and the existing Settings
appearance mutation path. No data migration is needed.

`Settings > Appearance` on macOS no longer shows the `Timeline Row` card. iOS
and shared timeline row rendering continue to use the same preference.

## Consequences

- Mac timeline filtering and row appearance now live in one timeline
  customization surface.
- Existing timeline row visibility choices keep working because storage is
  unchanged.
- Settings diagnostics, backup/import preference mirroring, and non-macOS
  timeline appearance controls keep using the same shared preference.
