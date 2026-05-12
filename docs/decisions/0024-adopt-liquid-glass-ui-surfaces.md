# 0024: Adopt Liquid Glass UI Surfaces

## Status

Accepted

## Date

2026-05-12

## Context

Routina had adopted Liquid Glass in a small part of the macOS Home detail mode picker, but most custom app surfaces still used opaque fills, `regularMaterial`, `ultraThinMaterial`, `.bar`, or hand-tuned opacity backgrounds. That made the app feel visually split between old custom chrome and the current iOS/macOS system design.

The app also has many shared SwiftUI components compiled into both iOS and macOS targets, so one-off per-screen styling would make the migration hard to preserve.

## Decision

Routina uses shared Liquid Glass surface modifiers for custom cards, panels, chips, and floating controls. On iOS 26 and macOS 26+, these surfaces use native `glassEffect` with semantic tinting and interactive glass only for tappable or focusable surfaces. Older platform builds keep material-based fallbacks through the same modifiers.

Standard system structures such as split views, toolbars, forms, and sheets should remain system-native. Custom opaque backgrounds behind macOS split-view details, sidebars, and toolbar-adjacent surfaces should be avoided unless a product reason requires them.

## Consequences

- New custom UI surfaces should prefer the shared Routina glass modifiers instead of direct `.background(.regularMaterial)`, `.background(.ultraThinMaterial)`, or opaque card fills.
- Semantic color remains available through glass tinting for status, tags, planner blocks, focus, sleep, and place surfaces.
- Shared components can preserve older-OS fallback behavior without repeating availability checks.
- Future visual work should remove remaining old custom fills when touching those areas instead of adding new one-off material styling.
