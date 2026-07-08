# 0347 Split Mac Future Tag Groups By Task Kind

Status: Accepted

Date: 2026-07-07

Refines: [0283 Preserve Mac Future Inner Sections](0283-preserve-mac-future-inner-sections.md), [0314 Remove Status Grouping and Collapse Deadline Groups](0314-remove-status-grouping-and-collapse-deadline-groups.md), [0346 Add Mac Future Bulk Subsection Actions](0346-add-mac-future-bulk-subsection-actions.md)

Refined by: [0351 Collapse Mac Future Tag Task Kind Subsections](0351-collapse-mac-future-tag-task-kind-subsections.md)

## Context

Mac `Future` already preserves tag groups inside the collapsed Future wrapper. A tag can still mix one-off todos and recurring routines, which makes dense future work harder to scan when the user wants to separate capture-style todos from cadence-based routines.

## Decision

Mac Home adds a persistent Task List Sort option, visible when grouping is `Tags`, to separate todos and routines inside mixed `Future` tag groups.

When the option is enabled, mixed tag and untagged groups keep their existing parent tag surface, color, count, collapse state, and manual-order section identity. Inside that parent group, non-collapsible `Todos` and `Routines` child subsections render the corresponding rows. Tag groups with only one task kind stay as direct rows to avoid unnecessary extra headers.

The option is stored with the other app task-list preferences and included in user-preference backup and restore.

## Consequences

Users can keep tag grouping as the primary Future organization while distinguishing todos from routines within a tag.

Bulk expand/collapse actions still operate on the existing parent tag groups, not the presentational child subsections.
