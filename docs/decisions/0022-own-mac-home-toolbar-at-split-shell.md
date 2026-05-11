# 0022: Own Mac Home Toolbar at the Split Shell

## Status

Accepted

## Date

2026-05-11

## Context

Mac Home uses a `NavigationSplitView` whose sidebar can collapse. Toolbar items that are attached to the sidebar column are re-laid out by AppKit when that column collapses, which makes global counters and split-view controls appear to jump. The non-full-size titlebar chrome also caused the split view to render a second rounded content corner below the real window corner.

## Decision

Global Home toolbar content is owned by the root split-view shell, not by the sidebar column. Per-detail toolbar controls can still be attached by detail views, but counters and global Home actions should not depend on whether the sidebar column is expanded.

The Home window uses a full-size transparent titlebar with unified toolbar styling so the split view and window chrome share one top edge.

## Consequences

- Collapsing or expanding the sidebar does not re-home the global counters.
- The sidebar toggle and global toolbar controls stay in the same toolbar layout.
- The top-left window chrome avoids stacking a content-corner curve under the real window corner.
- Future Mac Home modes should add global toolbar items at the split shell, not inside `macSidebarContent`.
