# 0245 Retire Pending Focus Assignment UI

Status: Accepted

Date: 2026-06-15

Refines: [0244 Start Mac Toolbar Focus With Task Picker](0244-start-mac-toolbar-focus-with-task-picker.md), [0106 Support Unassigned Watch Focus Sessions](0106-support-unassigned-watch-focus-sessions.md)

Refined By: [0333 Move Mac Focus Control to Planner Calendar Header](0333-move-mac-focus-control-to-planner-calendar-header.md)

## Context

Mac Focus starts now require selecting a task or tag before the timer starts. That makes newly created Focus sessions attributed from the beginning, so the primary Focus entry no longer needs an `Assign Pending Focus` action for later attribution.

The Stats dashboard also exposed an `Unassigned Focus` assignment card. With the primary focus start flow requiring task selection, keeping this card prominent makes the app suggest a cleanup workflow that users should not normally need.

## Decision

The primary Mac `Start Focus Timer` menu only starts attributed focus timers. It does not show `Assign Pending Focus`. [0333](0333-move-mac-focus-control-to-planner-calendar-header.md) later moves this menu from the Home toolbar to the Planner Calendar header.

Stats dashboards no longer surface the `Unassigned Focus` assignment card on macOS or iOS. The dashboard enum case remains readable for saved preference compatibility, but it is no longer available to show or add.

The underlying unassigned focus model and assignment helpers remain in place for legacy data, Watch/import compatibility, and planner-specific flows that intentionally use unassigned focus.

## Consequences

The primary focus UI stays simpler: start a timer by choosing a task, then manage the running task timer.

Existing saved dashboard order strings that mention `unassignedFocus` do not break, but the item is filtered out of available dashboard content.
