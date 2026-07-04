# 0244 Start Mac Toolbar Focus With Task Picker

Status: Accepted

Date: 2026-06-14

Refines: [0205 Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md)

Refined By: [0333 Move Mac Focus Control to Planner Calendar Header](0333-move-mac-focus-control-to-planner-calendar-header.md)

## Context

Mac exposes a compact `Start Focus Timer` menu. The earlier plan-focus behavior started unassigned focus directly, then asked the user to assign time after the session was finished. That made quick focus starts lightweight, but it also made the primary Focus entry poor for the common case where the user already knows which task they are about to work on.

## Decision

The Mac `Start Focus Timer` duration choices open a task picker sheet before starting focus. The sheet shows a search field and active, assignable tasks; selecting a task starts a normal task-backed focus session with the chosen count-up or fixed duration. [0333](0333-move-mac-focus-control-to-planner-calendar-header.md) later moves this primary Focus entry from the Home toolbar to the Planner Calendar header.

Unassigned plan focus remains available from planner and section flows that intentionally support allocation after the fact. Completed unassigned sessions can still be assigned from Stats and compatibility pending-focus assignment surfaces.

## Consequences

Primary Focus starts are attributed immediately, preserving task-backed planner sync, widgets, stats, shielding, and Live Activity behavior without a later allocation step.

The primary Focus menu no longer creates new unassigned plan focus sessions from duration choices, so future plan-focus work should keep allocation-first behavior on planner-specific surfaces rather than reintroducing it into the primary Focus entry.
