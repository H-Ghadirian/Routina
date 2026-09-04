# 0736 — Give iOS Workspaces Scope-Aware Controls

## Status

Accepted

## Date

2026-09-04

## Refined By

- [0737 — Summarize Active Workspace Controls in Place](0737-summarize-active-workspace-controls-in-place.md) makes non-default Backlog and Task Ladder state readable before opening the controls.

## Refines

- [0089 — Prefer Native Apple Platform Patterns](0089-prefer-native-apple-platform-patterns.md)
- [0734 — Share Task-Row Semantics Without Flattening Workspace Context](0734-share-task-row-semantics-without-flattening-workspace-context.md)

## Complements

- [0721 — Customize Mac Backlog Row Appearance](0721-customize-mac-backlog-row-appearance.md)
- [0722 — Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)

## Context

Backlog and Task Ladder use shared task-row semantics across iPhone and Mac, but
their iPhone controls did not support the same decisions. iPhone Backlog exposed
only Search and Refresh even though its shared feature already supported the Mac
workspace's complete filter and due-date sort model. iPhone Task Ladder exposed
Rank by, Base/Now, and current Order permanently above the list while Mac grouped
the equivalent concepts as View and Sort controls.

The controls should use recognizable terms and meanings on both platforms
without copying a Mac companion pane or Mac row-density preferences into a
compact phone interface.

## Decision

iPhone Backlog and Task Ladder use one shared workspace-control toolbar entry.
The entry presents a native sheet, uses the same icon and customized-state tone,
and leaves Search and explicit Refresh as direct workspace actions.

Backlog separates `Filter` and `Sort`. Filter exposes the complete existing
Backlog-owned model: task type, created date, due status, one-time state, current
Importance and Urgency thresholds, minimum Pressure, exact Thinking needed,
estimate and media presence, Tags, and iOS-visible Flags. Tag and Flag rules can
include or exclude values and preserve their All/Any meanings. Sort offers
Default, Due Soonest, and Due Latest. Each tab identifies non-default state and
resets only itself, preserving the other tab.

Task Ladder separates `View` and `Sort`. View owns the ranking metric and Base or
Now values where supported. Sort owns the selected metric's remembered direction.
The permanent list-level ranking controls are removed so ranked content starts at
the top of the list; navigation back to a prior scoped ladder remains structural
list context. Reset is scoped to the selected control tab.

iPhone does not gain Mac's row `Appearance` tabs. Its compact semantic row
renderer remains the deliberate phone presentation, while Mac keeps independent
durable Appearance choices for Main Task List, Backlog, and Task Ladder.
Cross-platform integrity means the same available task facts, filter rules, sort
meaning, and control vocabulary—not identical layouts or synchronized density.

## Consequences

- A person can narrow and order Backlog on iPhone using the same rules available
  on Mac instead of switching devices for review.
- Backlog and Task Ladder controls have one predictable iPhone entry and clearly
  separate membership, ordering, and Ladder view choices.
- Active controls remain discoverable from the toolbar and within their tab, and
  Reset does not erase unrelated control state.
- Task Ladder dedicates more initial screen space to ranked work while retaining
  explicit View, Sort, Search, Refresh, and scoped navigation.
- Phone and Mac remain platform-native; Mac density customization does not make
  the compact iPhone rows unstable or overly configurable.
