# 0419: Use Lightweight Surfaces Inside Unbounded Scroll Rows

## Status

Accepted

## Date

2026-07-23

## Context

Routina's Liquid Glass convention gives bounded controls and cards a consistent
native appearance. Production profiling of the Mac Planner Timeline showed a
different cost profile for repeated row decorations: every visible Timeline row
owned separate glass icon and kind-badge effects. A full newest-to-oldest
traversal continuously created and composited those effects as native `List`
reused rows. Older MacBook Air GPUs were especially sensitive to that repeated
backdrop work.

The row decorations carry semantic tint but do not need independent backdrop
sampling or interaction.

## Decision

Small repeated decorations inside unbounded scrolling rows use lightweight
shape fills with the same semantic tint and geometry instead of per-row glass
effects. Liquid Glass remains the default for bounded cards, panels, floating
controls, and interactive surfaces.

This exception applies when all of the following are true:

- the decoration repeats in an unbounded or production-scale scrolling list;
- it is not independently interactive;
- a simple rounded or capsule fill preserves its information and hierarchy.

Persistence-driven Home refresh notifications are also coalesced before a full
reload starts. The refresh rechecks the established scroll quiet gate after the
coalescing delay, preventing near-gesture notifications from beginning
whole-model work on the main actor.

## Consequences

- Timeline scrolling avoids continuously creating native glass backdrop layers
  for icons and kind badges.
- Repeated row decorations remain tinted and visually distinct.
- Remote updates may appear a fraction of a second later, while correctness and
  the existing post-scroll refresh behavior are preserved.
- New unbounded row designs should treat native glass as a measured exception,
  not an automatic decoration.
