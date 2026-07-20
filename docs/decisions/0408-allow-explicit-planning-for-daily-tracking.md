# 0408 Allow Explicit Planning for Daily Tracking

Status: Accepted

Date: 2026-07-19

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0385 Use Gentle Routine Cadence for Tracking](0385-use-gentle-routine-cadence-for-tracking.md), [0400 Plan Tracking Rows Into Today](0400-plan-tracking-rows-into-today.md)

## Context

Tracking rows can use routine-like cadence, including checklist item runout. A daily item-runout Tracking row can still be something the user wants to remember tomorrow, such as a groceries tracker with no currently due items.

The previous daily-routine planning rule hid `Plan to do` for these rows because item-runout with a one-day item counted as daily for task-list placement. That made explicit planning unavailable exactly when the user wanted to place a Tracking row in `Tomorrow`.

## Decision

Tracking rows with cadence enabled support explicit stored `plannedDate` values even when their cadence makes them daily for task-list purposes. This includes daily interval Tracking, daily checklist-completion Tracking, and item-runout Tracking with one-day checklist items.

Daily non-Tracking routines still do not expose stored planned-date controls. They remain in the daily routine area because their cadence already makes them part of the daily work surface.

An explicit Tracking plan wins over the Tracking daily fallback: a Tracking row planned for today appears in `Today`, a Tracking row planned for tomorrow appears in enabled `Tomorrow`, and Planner day agendas include the date-only planned row for the selected day. Unplanned Tracking rows still stay in `Tracking` on Mac rather than being moved by cadence alone.

## Consequences

Users can put an item-runout Tracking row into tomorrow's task list without creating a separate one-off todo.

The `Plan to do` row-menu and task-form controls are available for cadence-enabled Tracking rows regardless of daily cadence. `None` Tracking remains record-only and does not store planned dates. Planning still does not create a reminder, deadline, availability bound, or stored Planner block.
