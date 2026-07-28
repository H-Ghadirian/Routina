# 0451: Let Users Reorder Mac Home Sidebar Sections

Date: 2026-07-28

Status: Superseded by [0453 Use Context Menu Actions to Reorder Mac Home Sections](../0453-use-context-menu-actions-to-reorder-mac-home-sections.md)

Refines: [0252 Stabilize Home Task List Presentation Identity](../0252-stabilize-home-task-list-presentation-identity.md), [0350 Add Optional Mac Tomorrow Task Section](../0350-add-optional-mac-tomorrow-task-section.md), [0394 Add Custom Mac Sidebar Task Sections](../0394-add-custom-mac-sidebar-task-sections.md), [0418 Keep Whole-History Work Out of Scrolling Render Paths](../0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0450 Use Progressive Custom Section Management](../0450-use-progressive-custom-section-management.md)

## Context

Mac Home constructed top-level task-list sections in a fixed presentation order.
That order gave new users a useful default, but it could not reflect personal
priorities once several custom work areas sat between the planning and Future
sections. Settings could reorder the custom-section catalog, but it could not
place a built-in section such as Future above Today or interleave built-in and
custom sections.

Section membership, task routing, and row manual-order buckets already use
stable identities. A display-order preference can therefore rearrange complete
section snapshots without changing which tasks they contain.

## Decision

Every materialized, durable top-level Mac Home task-list section exposes a drag
handle. Users can drag Pinned, Today, enabled Tomorrow, custom super sections,
Future, and Archived up or down. The resulting display order is persisted by
stable presentation section ID and is included in backup, import, reset, and
user-preference mirroring.

The fixed order from Decisions 0350 and 0394 remains the default only until the
user reorders sections. A stored display order supersedes those decisions'
fixed-placement clauses.

Display order is independent from task classification, custom-section catalog
order, automatic rules, planning projection, and per-section row order. Section
snapshots are still derived and deduplicated in semantic priority order, then
their complete top-level values are reordered at the presentation invalidation
boundary and row-number offsets are recalculated.

Temporarily absent sections retain their stored position. A newly available
section that has no stored position is inserted beside its nearest canonical
default neighbors. The temporary search-only `Search Results` section is not
reorderable and does not enter the durable order.

## Consequences

- The default sidebar remains familiar until a user deliberately customizes it.
- Built-in and custom sections can express the user's preferred review order.
- Reordering a section cannot change routing rules, planning state, or task-row
  manual order.
- Empty or filtered-out sections return to their previous relative position.
- The presentation cache invalidates when the order preference changes, so
  ordering work does not move into the scrolling render path.
