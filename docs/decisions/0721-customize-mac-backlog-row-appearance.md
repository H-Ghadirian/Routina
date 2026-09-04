# 0721: Customize Mac Backlog Row Appearance

## Status

Accepted

## Date

2026-09-04

## Revised By

- [0728: Scope Mac Backlog Reset to Each Control Tab](0728-scope-mac-backlog-reset-to-each-control-tab.md) replaces the combined transient Reset with independent Filter, Sort, and Appearance resets.
- [0723: Filter Mac Backlog by Due Status](0723-filter-mac-backlog-by-due-status.md) adds Has Due Date, Due Today, and Overdue choices to the independent Filter tab.

## Revises

- [0690: Place Mac Filters Beside Planner and Backlog Workspaces](0690-place-mac-filters-beside-planner-and-backlog-workspaces.md)
- [0716: Sort Mac Backlog by Due Date](0716-sort-mac-backlog-by-due-date.md)

## Refines

- [0038: Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0210: Store Durable Preferences in SwiftData](0210-store-durable-preferences-in-swiftdata.md)
- [0254: Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0419: Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md)
- [0663: Allow Optional Multiline Mac Task Titles](0663-allow-optional-multiline-mac-task-titles.md)

## Context

Backlog's companion surface mixed filtering and sorting in one continuous form. It also deliberately omitted row appearance, so a person could customize the Main Task List but could not choose how much context Backlog rows showed. Backlog review benefits from the same clear separation among narrowing, ordering, and display choices without implying that Backlog and the Main Task List share one row configuration.

Backlog is an unbounded scrolling surface. Enabling more fields must not move schedule, status, progress, checklist, or Flag derivation into SwiftUI row builders that run repeatedly while scrolling.

## Decision

- Mac Backlog's right-side companion and fullscreen surface uses separate `Filter`, `Sort`, and `Appearance` tabs, matching the Task List control pattern while retaining Backlog-owned meanings and state.
- `Filter` contains Backlog's existing type, status, created-date, Task Ladder, estimate, media, Tag, and Flag controls. `Sort` contains `Default`, `Due Soonest`, and `Due Latest`. Reset continues to restore only transient Backlog filters and ordering.
- `Appearance` owns an independent, durable Backlog row preference. It does not read or change Main Task List row appearance.
- Backlog row appearance can show or hide Icon, Row Color, Color Badge, Row Number, Repeating / One-time Badge, Status Badge, Schedule and Due Dates, Pressure, Progress, Steps and Checklist, Tags, and Flags. Places appears only while Places is available. Goals remains absent while Goals is unavailable to this surface.
- Backlog's existing sparse row remains the default: Icon and multiline titles are shown, while optional metadata fields are hidden. The Backlog path and the pinned marker remain stable structural context rather than optional appearance fields.
- Long Backlog titles may use the `Multiline Titles` choice independently from the Main Task List choice.
- The reducer's cached Backlog presentation precomputes every visible Backlog row's reusable appearance metadata and logical row number when task, settings, search, or filter state invalidates the snapshot. Scrolling row builders only select already-derived values from that snapshot.
- Tags and Flags use lightweight colored labels, and row colors use ordinary fills and strokes. Backlog rows do not create per-row Liquid Glass surfaces.
- The serialized Backlog row preference is mirrored through `RoutinaUserPreferences` and included in routine-data backup and restore.

## Consequences

- A person can narrow, order, and visually tune Backlog without scanning one mixed control surface.
- Main Task List and Backlog row density can evolve independently and persist across relaunch, synchronization, backup, and restore.
- Existing Backlog users retain the sparse, multiline presentation until they opt into more fields.
- Appearance changes do not move tasks, change Backlog paths, affect sorting, or reset filters.
- Rich rows do not add whole-list derivation to the scrolling render path.
