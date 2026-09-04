# 0738 — Label iOS Task-Row Badges Explicitly

## Status

Accepted

## Date

2026-09-05

## Refines

- [0188 — Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0734 — Share Task-Row Semantics Without Flattening Workspace Context](0734-share-task-row-semantics-without-flattening-workspace-context.md)

## Context

iPhone Backlog and Task Ladder share compact type and lifecycle badges so a task
keeps the same meaning between workspaces. In dark mode, rendering the symbol and
its small title with the same semantic tint made the wording visually recede.
Rows appeared to contain unexplained colored marks even though a title existed in
the view hierarchy. A person should not have to memorize color or symbol meaning
to understand whether a task is One-time, Repeating, To Do, or In Progress.

## Decision

The shared iPhone semantic row renders every visible task-type and lifecycle badge
with an explicit `Image` and `Text`. Type wording uses the compact `One-time` and
`Repeating` vocabulary already used throughout the product; lifecycle wording
continues to come from the shared semantic presentation.

Badge text uses the primary foreground color. Semantic tint is limited to the
supporting symbol and a restrained outline over a neutral fill, so meaning remains
available without color. Accessibility labels explicitly distinguish `Task type`
from `Status`. Badges retain their full intrinsic wording and stack vertically
when the horizontal row cannot fit them.

This applies through the existing shared renderer to iPhone Backlog and Task
Ladder. It does not add Mac Appearance controls to iPhone or erase either
workspace's distinct context.

## Consequences

- Type and status are understandable without recognizing a color or glyph.
- Dark mode and low-saturation semantic tones keep readable badge wording.
- Backlog and Task Ladder remain semantically consistent without becoming
  mechanically identical to Mac rows.
- Narrow widths may make a task row taller rather than hiding or compressing its
  semantic labels.
