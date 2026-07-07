# 0346 Add Mac Future Bulk Subsection Actions

Status: Accepted

Date: 2026-07-07

Refines: [0283 Preserve Mac Future Inner Sections](0283-preserve-mac-future-inner-sections.md), [0314 Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md)

## Context

Mac `Future` can contain many independently collapsible inner tag, untagged, or deadline-date groups. Preserving those groups is useful, but expanding or collapsing them one at a time becomes tedious when the future list is long.

## Decision

The Mac task-list `Future` header exposes context-menu actions for collapsible inner groups: `Expand All` and `Collapse All Subsections`.

`Expand All` opens the `Future` wrapper and expands every collapsible inner group. `Collapse All Subsections` also leaves the top-level `Future` wrapper open, but collapses every collapsible inner group so their headers remain visible.

Both actions reuse the existing stored inner-group collapse identifiers instead of adding a new persistence key. The top-level `Future` collapse state remains a separate sidebar preference.

## Consequences

Users can reset dense future grouping quickly without losing the distinction between collapsing the whole `Future` wrapper and collapsing its nested sections.

The menu only appears when `Future` has collapsible inner groups, so ungrouped future lists do not gain inert bulk actions.
