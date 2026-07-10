# 0360: Make Mac Archived Section Full-Bleed

## Status

Accepted

## Date

2026-07-09

## Refines

- [0285: Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md)

## Context

The Mac task list already uses full-bleed continuous surfaces for top-level `Today` and `Future` sections so the header and child rows read as one section. The top-level `Archived` section remained an inset rounded card, which made it look like a nested group even though it is a sibling of `Today` and `Future`.

## Decision

Render the top-level `Archived` section with the same continuous full-bleed surface treatment as `Today` and `Future`: shared header/content background, square horizontal edges, and horizontal separator rules without colored left or right borders.

`Archived` keeps its archived icon, secondary tint, count, collapse state, and disabled focus-start behavior.

## Consequences

- The three top-level task-list buckets read as peers in the Mac sidebar.
- Archived rows remain visually grouped without adding an inset card around the section.
- Nested future/tag sections can continue using their existing inset treatment inside top-level surfaces.
