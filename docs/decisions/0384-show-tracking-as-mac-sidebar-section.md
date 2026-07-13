# 0384 Show Tracking as Mac Sidebar Section

Status: Accepted

Date: 2026-07-13

Refines: [0285 Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md), [0347 Split Mac Future Tag Groups By Task Kind](0347-split-mac-future-tag-groups-by-task-kind.md), [0350 Add Optional Mac Tomorrow Task Section](0350-add-optional-mac-tomorrow-task-section.md), [0380 Add Record Task Type](0380-add-record-task-type.md), [0383 Use Tracking as Record Label](0383-use-tracking-as-record-label.md)

## Context

Tracking rows are for analyzing what happened and how time was spent. When they appear inside `Today`, `Tomorrow`, or `Future`, they read like planned obligations instead of time-analysis entries.

Users need a distinct Home sidebar place to review tracking rows without making tracking behave like dated or due work.

## Decision

Mac Home claims active unpinned tracking rows into a top-level collapsible `Tracking` section between optional `Tomorrow` and `Future`.

The section is shown only when at least one matching tracking row exists. Pinned tracking rows continue to appear in `Pinned`, and archived tracking rows continue to appear in `Archived`.

Tracking uses its own `tracking` manual-order key. If compatibility data or imported rows contain planned-date metadata on a tracking row, Mac Home still claims that row into `Tracking` instead of `Today`, `Tomorrow`, or `Future`.

## Consequences

Tracking remains visible for analysis without creating planning pressure.

Future Mac task-list grouping should keep tracking rows out of date/planning buckets unless a later decision explicitly opts tracking into scheduling behavior.
