# 0351 Collapse Mac Future Tag Task Kind Subsections

Status: Accepted

Date: 2026-07-08

Refines: [0346 Add Mac Future Bulk Subsection Actions](0346-add-mac-future-bulk-subsection-actions.md), [0347 Split Mac Future Tag Groups By Task Kind](0347-split-mac-future-tag-groups-by-task-kind.md)

## Context

[0347](0347-split-mac-future-tag-groups-by-task-kind.md) introduced presentational `Todos` and `Routines` child subsections inside mixed `Future` tag groups, but kept those child subsections non-collapsible. Dense future tag groups can still need separate scanning control for todos and routines after the parent tag is expanded.

## Decision

When the tag task-kind split is enabled, mixed `Future` tag and untagged groups render `Todos` and `Routines` as independently collapsible child subsections.

Child subsection collapse identity is scoped by the parent section identity and the child task kind, so collapsing `Todos` under one tag does not collapse `Todos` under another tag. The child groups remain presentational: they do not own manual task ordering or change the parent tag group's color, count, move context, or collapse identity.

`Future` header `Expand All` and `Collapse All Subsections` actions include every collapsible descendant group, including these `Todos` and `Routines` child subsections.

## Consequences

Users can expand a tag and then independently hide either todos or routines inside that tag.

Bulk expand/collapse covers the full visible `Future` inner hierarchy, not just the first level of tag or deadline groups.
