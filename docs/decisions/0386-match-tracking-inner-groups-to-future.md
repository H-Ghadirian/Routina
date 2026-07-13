# 0386 Match Tracking Inner Groups to Future

Status: Accepted

Date: 2026-07-13

Refines: [0285 Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md), [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md)

## Context

Tracking is a top-level Mac Home section, but its rows should still feel like normal routine rows collected into the task-list surface. Keeping Tracking visually too distinct makes the section read like a separate task type instead of a routine-like analysis area.

## Decision

Mac Home renders Tracking's expanded inner groups with the same grouping structure used inside `Future` for the active task-list grouping mode. Tags, deadline/status buckets, and ungrouped rows keep the same inner group affordances they would have under `Future`, while the top-level section remains titled `Tracking`.

The top-level Tracking surface uses the same neutral section tint treatment as `Future`. Tracking rows continue to use the `tracking` manual-order key for their section-level order.

## Consequences

Tracking stays visually aligned with the main task list while remaining separated from planned and future work.

Future visual changes to `Future` inner grouping should consider whether Tracking should receive the same treatment.
