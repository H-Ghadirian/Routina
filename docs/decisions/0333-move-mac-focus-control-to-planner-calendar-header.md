# 0333: Move Mac Focus Control to Planner Calendar Header

## Status

Accepted

## Date

2026-07-04

## Refines

- [0244: Start Mac Toolbar Focus With Task Picker](0244-start-mac-toolbar-focus-with-task-picker.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)
- [0317: Use Principal Search in the Mac Home Toolbar](0317-use-principal-search-in-mac-home-toolbar.md)
- [0319: Open Planner Filters in the Home Filter Pane](0319-open-planner-filters-in-home-filter-pane.md)

## Context

Mac Home's command row became crowded as search, global navigation, Add, and Focus all lived in titlebar-adjacent chrome. Focus is most useful while planning or working from the calendar, and the Planner Calendar header already owns local work controls such as filters and date/range navigation.

Keeping Focus in the global Home toolbar also made the top chrome feel less stable when the app window, sidebars, companion panes, and search expansion changed available toolbar space.

## Decision

Mac Home no longer shows the Focus start/control branch in the top toolbar command row. The Planner Calendar header shows the Focus control beside the Planner filter button.

The moved control keeps the existing behavior from [0244](0244-start-mac-toolbar-focus-with-task-picker.md): duration choices open the task picker before starting task-backed focus. If an unassigned plan-focus session is active, the header shows the plan-focus pause/resume/finish/abandon menu. If another focus timer is active, the header shows the active focus badge while hiding only unassigned plan-focus status.

The Focus control is Calendar-local and does not render in Planner Timeline mode. Search remains in the principal/top search surface, and the Home toolbar command row keeps Home navigation, Add, Places when enabled, and optional progress controls.

## Consequences

- The top Home toolbar is quieter and gives search/navigation more room.
- Starting focus is closer to the calendar planning workflow.
- Planner Timeline keeps its filter access without gaining a Calendar-specific Focus button.
- Future Focus placement work should preserve this Calendar-header ownership unless a later decision explicitly moves Focus again.
