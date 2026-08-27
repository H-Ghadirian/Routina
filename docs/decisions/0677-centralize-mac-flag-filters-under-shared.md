# 0677: Centralize Mac Flag Filters Under Shared

## Status

Accepted

## Date

2026-08-27

## Revises

- [0498: Filter Task Lists by Flags](0498-filter-task-lists-by-flags.md)
- [0582: Hide Flagged Task Activity From Timeline](0582-hide-flagged-task-activity-from-timeline.md)
- [0672: Align Mac Task and Timeline Flag Filters With Tags](0672-align-mac-task-and-timeline-flag-filters-with-tags.md)

## Refines

- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0660: Make Mac Planner Filters Explicit, Composable, and Bounded](0660-make-mac-planner-filters-explicit-composable-and-bounded.md)
- [0671: Present Mac Shared Tags as Direct Actions](0671-present-mac-shared-tags-as-direct-actions.md)
- [0674: Hide Flagged Tasks From Calendar List](0674-hide-flagged-tasks-from-calendar-list.md)

## Context

Flags are task behavior markers whose assignments matter across several task-backed
surfaces. Mac Filters nevertheless exposed Flag selection separately in Task List
and Timeline, while Calendar inherited the resulting task filtering without owning
an equivalent control. That duplication made the scope of a selection unclear and
left no consistent place to temporarily exclude tasks carrying a Flag.

Calendar's `Assumed done` control is different: it controls whether one Calendar
activity layer is visible. The `Auto Assume Done` Flag changes task behavior and can
be combined with other Flags, while the layer toggle does not assign or filter Flags.

## Decision

Mac Filters puts Flag filtering in `Shared`, beside the other task attributes that
apply across surfaces. It offers direct searchable `Include flags` and `Exclude
flags` actions, returns selections as removable chips, and shows an independent
`All` / `Any` match choice only when that side contains multiple Flags. Task List,
Timeline, and Calendar do not duplicate these Flag controls.

The one Shared rule applies to the Mac Task List, task-backed Planner Timeline
activity, Calendar Schedule tasks, and every Calendar List task section. Standalone
Timeline records have no task Flag assignment and are therefore unaffected. Stats
keeps its independent Flag filters because it is a separate analytical scope.

An Include selection is an explicit recovery request: a matching task may appear
even when the selected built-in Flag normally hides it from that surface. This also
lets a person temporarily reveal tasks carrying `Hide from Calendar List`. Exclude
is evaluated after Include and wins when the same task matches both rules. With no
Include selection, every built-in hiding behavior keeps its normal default effect.

The `Hide from Calendar List` behavior remains unchanged by default: assigned tasks
are omitted from Planned tasks, Assumed done, Confirmed assumed done, and Done, plus
their counts. Calendar's separate `Assumed done` layer toggle stays in Calendar
filters because it controls Calendar-layer visibility rather than Flag matching.

Existing temporary Task List and Timeline Include selections are merged into the
Shared selection and synchronized for compatibility. Shared exclusions and their
match mode are stored with the existing temporary Home filter snapshot. Task and
Timeline presentations consume cached Flag catalogs and derived membership so Flag
matching does not move whole-history work into scrolling row builders.

## Consequences

- A person defines one temporary Flag rule for every task-backed Mac planning view.
- Include and Exclude use the same compact interaction as Shared Tags without
  repeating a complete Flag catalog inline.
- Include provides a deliberate inspection path for every normally hidden behavior;
  Exclude provides the final veto when rules overlap.
- The Calendar `Assumed done` toggle remains understandable as a layer choice rather
  than being presented as a second Flag filter.
- iOS and Stats retain their existing surface-specific filter presentations.
