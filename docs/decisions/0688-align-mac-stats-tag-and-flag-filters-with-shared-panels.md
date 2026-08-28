# 0688: Align Mac Stats Tag and Flag Filters with Shared Panels

## Status

Accepted

## Date

2026-08-27

## Revises

- [0658: Defer Mac Stats Tag Catalog to Searchable Pickers](0658-defer-mac-stats-tag-catalog-to-searchable-pickers.md)
- [0671: Present Mac Shared Tags as Direct Actions](0671-present-mac-shared-tags-as-direct-actions.md)
- [0672: Align Mac Task and Timeline Flag Filters with Tags](0672-align-mac-task-and-timeline-flag-filters-with-tags.md)
- [0677: Centralize Mac Flag Filters under Shared](0677-centralize-mac-flag-filters-under-shared.md)
- [0678: Group Mac Shared Tag and Flag Actions](0678-group-mac-shared-tag-and-flag-actions.md)
- [0679: Edit Mac Shared Tag and Flag Rules in Combined Popovers](0679-edit-mac-shared-tag-and-flag-rules-in-combined-popovers.md)
- [0683: Omit Idle Copy from Mac Shared Filter Groups](0683-omit-idle-copy-from-mac-shared-filter-groups.md)

## Refines

- [0188: Prefer Self-Explanatory UI over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0418: Keep Whole-History Work out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0549: Filter Stats by Task Flags](0549-filter-stats-by-task-flags.md)

## Context

Planner Shared established one compact interaction for each multi-value filter
family: an always-expanded colored panel, visible active-rule summaries, and one
combined Include/Exclude searchable popover. Mac Stats still presented Tags in
a disclosure card and Flags in a separate disclosure that expanded the complete
catalog inline.

The different outer interactions made equivalent filter choices feel unrelated
and made the Stats sidebar taller and less predictable. Stats still needs its
own analytical scope; matching a Planner task view and filtering a Stats report
must not silently share state.

## Decision

- Mac Stats presents Flags first in the same titled orange panel used by Planner
  Shared, followed by Tags in the same titled teal panel used by Planner Shared.
- Each panel is always expanded and has one full-width edit action. That action
  opens the shared combined Include/Exclude searchable popover.
- Active Include and Exclude rules remain visible outside the popover as
  directly removable summaries. `All` / `Any` appears in the popover only when
  the selected side contains multiple values. An idle panel puts its edit action
  directly below the title without empty-state copy.
- Stats continues to use its own persisted Include/Exclude selections, match
  modes, and analytical derivation. Planner Shared and Stats do not synchronize
  filter state.
- Stats keeps its existing Tag counts, colors, bounded related suggestions, and
  mutations. Flag selection keeps the Stats rule that one Flag cannot be active
  on both sides.
- A panel remains visible when it has a stored active rule even if the current
  catalog is temporarily empty. iOS Stats filtering does not change.
- Mac Stats reuses the Planner panel components so their layout, full-surface
  hit areas, search behavior, and active-rule presentation remain aligned.

## Consequences

- People use one recognizable Flags and Tags interaction in both Mac Planner
  filters and the Mac Stats sidebar.
- Stats preserves its separate analytical meaning and persistence despite the
  shared presentation.
- Large Flag and Tag catalogs remain outside normal sidebar rendering and are
  browsed only when requested.
