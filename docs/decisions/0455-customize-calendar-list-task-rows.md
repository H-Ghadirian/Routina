# 0455: Customize Calendar List Task Rows

Date: 2026-07-28

Status: Accepted

Refines: [0038 Configure Home Task Row Fields](0038-configure-home-task-row-fields.md), [0222 Configure Timeline Row Fields](0222-configure-timeline-row-fields.md), [0254 Move Mac Task Row Appearance to Home Filter Detail](0254-move-mac-task-row-appearance-to-home-filter-detail.md), [0369 Show Day Task List Columns in Planner Calendar](0369-show-day-task-list-columns-in-planner-calendar.md)

## Context

Mac Task List and Timeline filters already keep row-appearance controls beside the surface they affect. Planner Calendar `List` uses its own compact day-agenda row, but the Calendar filter detail exposed only layer visibility. Users could not simplify Calendar rows without also expecting unrelated Task List settings to change.

Calendar `List` rows currently have three optional presentation elements: the task icon, the placement line containing time and duration, and the task-specific row tint. The task title and any eligible inline completion-resolution actions are structural and must remain available.

## Decision

The Mac Calendar filter detail has `Filter` and `Appearance` tabs. `Appearance` owns a dedicated `Calendar Task Row` setting with independent controls for:

- `Icon`
- `Time and Duration`
- `Row Color`

The setting stores hidden fields in `appSettingDayPlanCalendarListRowHiddenFields`. All fields are visible by default, and the preference is mirrored into user preferences and included in backup/import.

The setting applies to the shared Planner day-task row used by Calendar `List` columns and the focused day-task sidebar. Narrow Calendar columns may still hide an enabled icon when preserving readable title space requires it. The title, section grouping, row identity, inline resolution actions, Planner records, and task data are unaffected.

## Consequences

- Users can tune Calendar row density without changing Task List or Timeline rows.
- Calendar filters keep appearance controls beside the Calendar presentation they affect.
- Calendar `List` and the focused day-task sidebar remain visually consistent because they consume the same row visibility value.
- New optional Calendar day-task row elements should join the dedicated field model and default to visible unless product behavior requires otherwise.
