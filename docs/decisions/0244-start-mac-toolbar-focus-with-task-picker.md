# 0244 Start Mac Toolbar Focus With Task Picker

Status: Accepted

Date: 2026-06-14

Refines: [0205 Run Plan Focus From Planner](0205-run-plan-focus-from-planner.md)

## Context

The Mac Home toolbar exposes a compact `Start Focus Timer` menu. The earlier plan-focus behavior started unassigned focus directly from the toolbar, then asked the user to assign time after the session was finished. That made quick focus starts lightweight, but it also made the toolbar poor for the common case where the user already knows which task they are about to work on.

## Decision

The Mac Home toolbar `Start Focus Timer` duration choices open a task picker sheet before starting focus. The sheet shows a search field and active, assignable tasks; selecting a task starts a normal task-backed focus session with the chosen count-up or fixed duration.

Unassigned plan focus remains available from planner and section flows that intentionally support allocation after the fact. Completed unassigned sessions can still be assigned from Stats and from the toolbar's pending-focus assignment surface.

## Consequences

Toolbar-started focus is attributed immediately, preserving task-backed planner sync, widgets, stats, shielding, and Live Activity behavior without a later allocation step.

The toolbar no longer creates new unassigned plan focus sessions from duration choices, so future plan-focus work should keep allocation-first behavior on planner-specific surfaces rather than reintroducing it into the global Home toolbar.
