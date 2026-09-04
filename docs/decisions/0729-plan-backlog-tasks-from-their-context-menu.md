# 0729 — Plan Backlog Tasks From Their Context Menu

Date: 2026-09-04

Status: Accepted

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0363 Gate Mac Plan Tomorrow Menu Item](0363-gate-mac-plan-tomorrow-menu-item.md), [0546 Separate Mac Backlog From the Radar Sidebar](0546-separate-mac-backlog-from-the-radar-sidebar.md)

## Context

Mac Backlog task rows could open a task or change its Backlog placement, but setting a planned date required leaving that row context and using another task-editing surface. Backlog placement and lightweight day planning are independent, so organizing a task off the main list should not prevent the person from deciding when to work on it.

## Decision

Eligible Mac Backlog task rows expose the same `Plan to do` context-menu choices as the Main Task List: `Today`, an optional `Tomorrow` shortcut while the Tomorrow section is enabled, `Choose Date...`, and `Clear Plan` when a plan exists.

Backlog uses the established task-planning eligibility and date normalization contract. Setting or clearing a plan updates the cached Backlog presentation and persists the task without changing its Backlog section, Flag behavior, availability, deadline, reminder, or Planner blocks. Daily routines and other tasks that do not support stored planning omit the submenu.

## Consequences

- Deferred work can be planned directly where it is reviewed.
- Planning a Backlog task keeps the person in Backlog and keeps the task in its existing Backlog path.
- The Tomorrow shortcut remains aligned with the visibility of the Tomorrow section, while the date picker still supports any date.
- The Main Task List and Backlog share one planning mutation contract even though their row menus use different presentation implementations.
