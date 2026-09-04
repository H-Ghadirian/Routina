# 0734 — Share Task-Row Semantics Without Flattening Workspace Context

## Status

Accepted

## Date

2026-09-04

## Refined By

- [0735 — Compose Main Task List From Shared Task-Row Semantics](0735-compose-main-task-list-from-shared-task-row-semantics.md) brings Main Task List identity and stable lifecycle meaning into the shared snapshot while preserving its richer occurrence and action context.
- [0738 — Label iOS Task-Row Badges Explicitly](0738-label-ios-task-row-badges-explicitly.md) makes the shared iPhone type and status treatment text-first while preserving the semantic vocabulary and adaptive compact layout.

## Refines

- [0038 — Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0089 — Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0571 — Show Task Identity Metadata in Mac Task Ladder](0571-show-task-identity-metadata-in-mac-task-ladder.md)
- [0593 — Show Relationship Blocking in Home Task Rows](0593-show-relationship-blocking-in-home-task-rows.md)
- [0595 — Keep Task Completion Colors Consistent Across Platforms](0595-keep-task-completion-colors-consistent-across-platforms.md)
- [0721 — Customize Mac Backlog Row Appearance](0721-customize-mac-backlog-row-appearance.md)
- [0722 — Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)

## Context

The Main Task List, Backlog, and Task Ladder answer different questions, and
iPhone and Mac have different space and interaction strengths. Their rows had
therefore evolved independently. That was appropriate for layout and controls,
but not for the task facts themselves: the same task could be described with
different identity treatment or status context depending on where it appeared.

A person should recognize a task immediately when moving between workspaces or
devices. At the same time, forcing identical rows or identical filter, sort, and
appearance controls everywhere would obscure why each workspace exists.

## Decision

Backlog and Task Ladder share one immutable semantic row presentation for task
identity, task type, lifecycle status, due/schedule text, progress, next-step or
checklist context, place, Tags, Flags, image/pin state, task color, and semantic
status tone. Relationship-derived blocking is resolved from the same task and
completion-history inputs used by Home before the Backlog snapshot is built.
Terminal lifecycle state takes precedence over relationship blocking.

The shared presentation defines meaning, not layout. Each workspace owns its
membership, filtering, ordering, structural context, actions, and density:

- Main Task List continues to emphasize what is actionable now and retains its
  richer occurrence, location, planning, and configurable row presentation.
- Backlog emphasizes the task's deferred path, due/schedule context, and next
  step so the person can decide whether to plan, move, or leave it deferred.
- Task Ladder emphasizes the selected metric, rank section, group identity,
  inheritance, temporal weighting, and child count.

iOS Backlog and Task Ladder use one native semantic row renderer for task icon,
title, task type, status, and tone while supplying their own context beneath it.
Task Ladder container groups and task groups remain shape-distinct. Mac keeps
the independent Appearance preferences established for Main Task List, Backlog,
and Task Ladder; hiding a field changes density, never the field's meaning.

All semantic presentations, including search results, are created when the
feature snapshot rebuilds. Scrolling row builders only select cached values and
compose lightweight SwiftUI views.

## Consequences

- A task keeps recognizable identity, status wording, icons, and color meaning
  between Backlog and Task Ladder and across iPhone and Mac.
- Backlog now reports unresolved relationship blocking instead of simultaneously
  presenting the stored Ready or In Progress state.
- Workspace filters and sorts can change which tasks appear and in what order,
  but cannot silently redefine the task facts shown by a row.
- Platform and workspace layouts can continue to evolve independently without
  duplicating semantic task-row derivation.
- Home's richer cached occurrence presentation is not reduced to Backlog or
  Ladder's smaller vocabulary; future convergence must preserve that context.
