# 0285 Clarify Mac Sidebar Section Surfaces

Status: Accepted

Date: 2026-06-26

Refines: [0283 Preserve Mac Future Inner Sections](0283-preserve-mac-future-inner-sections.md)

## Context

The Mac Home sidebar needs to make section ownership clear without wasting horizontal space. After moving future tasks under a `Future` wrapper, the today section could read like a detached header followed by unrelated task cards because the blue-tinted surface stopped at the header.

Task rows also need a small gap between cards so dense planned lists remain scannable.

## Decision

The planned-today section is titled `Today` in the Mac sidebar. `Today` and `Future` use continuous full-bleed section surfaces: each section's header and expanded content share the same tinted background, while child content keeps internal padding and spacing.

`Future` remains a wrapper for nested tag sections and other inner groups. Nested tag sections keep their own surfaces and collapse state inside the shared `Future` surface.

Top-level `Today` and `Future` surfaces use square horizontal edges and horizontal separator lines only. They do not draw colored left or right borders, so they read as part of the sidebar rather than separate inset cards.

Task rows in the Mac sidebar have consistent vertical spacing between cards, including rows that come from adjacent merged planned/daily groups.

## Consequences

Today's task rows visually belong to `Today`, and future task groups visually belong to `Future` while still keeping their nested tag affordances.

The top-level `Today` and `Future` header surfaces align to the sidebar's horizontal edges; internal task content owns its own readable inset.
