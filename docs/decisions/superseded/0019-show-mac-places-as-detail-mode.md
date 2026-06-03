# 0019: Show Mac Places as a Detail Mode

## Status

Superseded

## Date

2026-05-10

## Supersedes

[0018: Show Mac Map Check-In in the Detail Column](0018-show-mac-map-check-in-in-detail-column.md)

## Superseded By

[0020: Show Mac Places as a Workspace](0020-show-mac-places-as-workspace.md)

## Context

Mac map check-in belongs in the main window, but treating it as a transient detail-column presentation created a second route through the split-view layout. That route had to coordinate separately with the sidebar and toolbar, which made the sidebar header spacing fragile.

The map is also becoming a durable place-analysis surface: it includes current-location check-in, saved places, and day timeline review. That fits the existing Mac detail-mode picker better than a temporary open/close presentation.

## Decision

Mac Home exposes Places as a fourth detail mode beside Details, Planner, and Board. The bottom check-in dock switches the window into the normal routines/detail context, resets the sidebar to the neutral all-tasks scope, and selects Places instead of opening a special map presentation. The detail-mode segmented control lives inside the detail column, not the titlebar, so it does not compete with the sidebar toolbar area.

The Mac home window explicitly disables full-size transparent titlebar content and uses a compact unified toolbar through a narrow AppKit configurator. This keeps the sidebar and detail content below the real window toolbar/titlebar in every detail mode instead of relying on per-view padding.

The Places detail also pins its Mac sidebar header and detail-mode picker with safe-area insets. MapKit can cause the embedded map surface to claim the top of its container during presentation changes, so the navigation chrome for Places is owned outside the map content itself.

The Places detail renders the map, current-location controls, saved places, and day timeline directly in the detail column.

## Consequences

- Places uses the same segmented detail picker as the rest of the Mac main window.
- The sidebar no longer needs map-specific toolbar or safe-area spacing adjustments.
- The titlebar remains reserved for app/window actions, avoiding titlebar-driven split-view layout shifts.
- Home window chrome is configured at the scene and fallback-window boundary, so future detail modes inherit the same titlebar-safe content area.
- Places keeps its own top navigation chrome outside the map surface, avoiding map-driven clipping of the sidebar header or detail picker.
- The bottom check-in dock remains a quick launcher and can still pass the selected activity into the Places detail.
- iPhone and watch check-in presentation behavior remains platform-owned and unchanged.
