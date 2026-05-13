# 0035: Place Mac Done Counter Beside Sidebar Toggle

## Status

Accepted

## Date

2026-05-13

## Supersedes

[0022: Own Mac Home Toolbar at the Split Shell](0022-own-mac-home-toolbar-at-split-shell.md) for Done counter placement only.

## Context

The Mac Home toolbar originally kept global counters in the root split-view shell so they would not move when the sidebar changed. After simplifying the top counters, the Done count became the one compact status badge the user wanted to keep visible near the sidebar controls.

Keeping Done grouped with Sleep in the root toolbar made it appear on the detail side of the split boundary, visually detached from the left sidebar. The desired layout is for Done to sit on the same toolbar row as the sidebar collapse control, immediately to the collapse control's left while the sidebar is expanded.

## Decision

The Mac Home Done counter is intentionally owned by the sidebar toolbar and placed as a trailing sidebar toolbar action. Sleep and the main Home detail mode picker remain owned by the root Home toolbar.

The Done counter uses the shared Mac toolbar status badge styling and appears beside the system sidebar collapse affordance instead of inside the sidebar body or the detail-side toolbar group.

## Consequences

- The Done counter visually belongs to the left sidebar header area.
- The collapse affordance and Done counter share one toolbar row.
- Collapsing the sidebar may hide the sidebar-owned Done counter; Stats remains the full destination for activity counts.
- Future Mac Home toolbar work should preserve this explicit exception rather than moving Done back into the root toolbar with other global actions.
