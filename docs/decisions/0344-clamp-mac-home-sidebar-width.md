# 0344: Clamp Mac Home Sidebar Width

## Status

Accepted

## Date

2026-07-05

## Refines

- [0343: Add Mac Home Sidebar Collapse Control](0343-add-mac-home-sidebar-collapse-control.md)

## Context

Mac Home already declares a preferred sidebar width range through SwiftUI, but the native split-view divider can still leave the left sidebar far wider than intended. That lets the sidebar cover most of the Planner and makes the main workspace hard to use.

## Decision

Mac Home clamps the left sidebar through the underlying split-view item, enforcing the existing Home sidebar minimum and maximum widths while the sidebar is visible. The explicit toolbar collapse control remains allowed and can still hide the sidebar entirely.

## Consequences

- Dragging the sidebar divider cannot make the left sidebar consume the main Planner or detail workspace.
- The existing collapse/expand action remains the way to intentionally hide or restore the sidebar outside the visible width range.
- The SwiftUI column width hint and the AppKit split-view clamp use the same width constants.
