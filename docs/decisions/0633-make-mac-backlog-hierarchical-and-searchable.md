# 0633: Make Mac Backlog Hierarchical and Searchable

## Status

Accepted

## Date

2026-08-22

## Refines

- [0419: Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0546: Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md)
- [0632: Integrate Mac Workspaces in the Main Window](0632-integrate-mac-workspaces-in-the-main-window.md)

## Context

Backlog already stored the same one-level super-section and subsection model as
the Mac Home task-list sidebar, but its presentation discarded catalog sections
that did not contain tasks. A newly created Backlog super section therefore
disappeared immediately, making its inline subsection action unreachable until
a task was assigned by another route.

Backlog also had no local search. Planner's toolbar search intentionally stays
hidden while Backlog owns the full workspace, but deferred work still needs to
be findable without returning it to the everyday Radar.

## Decision

Mac Backlog presents every Backlog super section and its one supported level of
subsections, including empty catalog entries. Both levels use full-width
collapsible headers with visible task counts. An expanded super section owns the
subsection-creation control, so a newly created empty section can immediately be
organized further.

The Backlog sidebar owns a local search field. Search filters the reducer-owned
Backlog presentation across task title, emoji, description, notes, destination,
tags, Flags, and explicit section path. Matching super-section/subsection paths
remain visible and are treated as expanded for the search session. Automatic
`Hidden by flag` tasks participate in the same query. A no-match query shows a
search empty state and does not offer task creation.

Search filtering and hierarchy construction happen only when task data, section
preferences, Flag rules, or search input changes. Scrolling rows consume that
cached snapshot and do not scan the full task catalog.

## Consequences

- Backlog's stored two-level organization is reachable before any task has been
  assigned.
- Search stays scoped to deferred Backlog work and does not acquire Planner
  Quick Add semantics.
- Clearing search restores the person's local disclosure choices because search
  expansion does not mutate them.
- The hierarchy remains capped at super section plus one subsection level.
