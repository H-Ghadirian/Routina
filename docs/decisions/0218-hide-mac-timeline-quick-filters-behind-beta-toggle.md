# 0218: Hide Mac Timeline Quick Filters Behind Beta Toggle

## Status

Accepted

## Date

2026-06-12

## Context

Mac Timeline exposes an always-visible quick filter strip for common timeline types such as All, Routines, Todos, Focus, Notes, Places, Emotions, and Sleep. The same filtering remains available from the full Timeline filter detail/sheet, so the quick strip is convenience chrome rather than required navigation.

Routina already uses Settings -> General -> Beta Experiments for optional Mac surfaces and denser chrome while default release UI stays quieter.

## Decision

Mac Timeline quick filters are hidden by default and controlled by the local `appSettingMacTimelineQuickFiltersVisible` beta flag in Settings -> General -> Beta Experiments.

When disabled, users can still filter Timeline by type from the full filter controls. When enabled, the quick filter strip appears in the Mac Timeline tab and Mac Home Timeline surfaces.

## Consequences

- Default Mac Timeline chrome is quieter.
- Users who prefer the quick type strip can opt back in from Beta Experiments.
- The detailed Timeline filter controls remain the stable discoverable path for type filtering.
