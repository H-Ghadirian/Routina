# 0400 Plan Tracking Rows Into Today

Status: Accepted

Date: 2026-07-17

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md), [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md), [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md)

## Context

Tracking rows have their own Mac sidebar section so analysis entries do not automatically read like obligations. That section remains useful for unplanned Tracking.

The `Plan to do` menu is explicit user intent, though. When a user chooses `Today` for a Tracking row, leaving the row in `Tracking` makes the action look broken even if the stored `plannedDate` changed.

## Decision

Mac Home lets active unpinned Tracking rows with an explicit `plannedDate` participate in the same planning buckets as other eligible tasks. A Tracking row planned for today appears in `Today`; if the optional Tomorrow section is enabled, a Tracking row planned for tomorrow appears in `Tomorrow`.

Custom sections still claim assigned rows before built-in planning. Planning a custom-section row clears the custom assignment, so it can move into `Today` or `Tomorrow`. Pinned and archived rows keep their existing priority.

Tracking cadence alone does not create planning placement. Unplanned active Tracking rows, including rows with interval or calendar cadence, stay in the top-level `Tracking` section and use the `tracking` manual-order key.

## Consequences

`Plan to do` is visually reliable for Tracking rows without making all Tracking cadence behave like dated work.

Existing Tracking rows that carry a `plannedDate` now surface in the matching planning section while active, unpinned, unarchived, and eligible for planning.
