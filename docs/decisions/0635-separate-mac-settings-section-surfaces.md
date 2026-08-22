# 0635: Separate Mac Settings Section Surfaces

## Status

Accepted

## Date

2026-08-22

## Refines

- [0285: Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md)
- [0419: Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md)
- [0634: Unify Mac Workspace Search and Creation](0634-unify-mac-workspace-search-and-creation.md)

## Context

Mac Settings stores the ordinary Radar task-list sections and Backlog sections
in one custom-section catalog. Showing that catalog as one flat list made a
section's destination unclear, especially after Backlog gained the same
super-section and subsection hierarchy as the task-list sidebar.

## Decision

Mac Settings -> Sections uses a segmented picker with two user-facing choices:
`Main task list` and `Backlog`. The selected segment scopes the visible
top-level section cards and the new-section composer. A section created from
the Backlog segment is stored with the Backlog surface; a section created from
the Main task list segment remains on the Radar surface. Subsections continue
to inherit their parent surface and remain edited inside that parent's card.

Section reordering is scoped to the selected surface for top-level sections;
it does not move a Radar section through a Backlog section (or vice versa).
The underlying catalog format and existing surface assignments do not change,
so this is a presentation and creation-scope clarification rather than a
migration.

## Consequences

- People can tell where a Settings section will appear before editing it.
- The section editor remains one compact catalog instead of duplicating the
  entire Settings screen.
- Existing sections keep their IDs, names, ordering data, rules, and surface.
- Section titles remain subject to the existing catalog naming rules.
