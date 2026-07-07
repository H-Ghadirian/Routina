# 0350: Add Optional Mac Tomorrow Task Section

Date: 2026-07-07

Status: Accepted

Refines: [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0202 Nest Daily Routines Under Mac Plan Today](0202-nest-daily-routines-under-mac-plan-today.md), [0281 Collapse Mac Future Tasks](0281-collapse-mac-future-tasks.md)

## Context

Mac Home previously grouped active unpinned work into `Today` and a collapsed-by-default `Future` wrapper. That kept the sidebar compact, but tomorrow-planned work still mixed with the larger Future set. Users who plan one day ahead need a quick review surface without changing the default compact behavior for everyone.

## Decision

Settings -> General -> Task List exposes `Show Tomorrow section`, defaulting off.

When enabled, Mac Home inserts a top-level `Tomorrow` section between `Today` and `Future`. It claims active unpinned todos and non-daily routines with an explicit planned date of tomorrow, plus weekly/month-day calendar routines whose configured occurrence is tomorrow. Those rows are removed from `Future` for that presentation.

`Tomorrow` has its own manual-order section key, `plannedTomorrow`, so row moves in Tomorrow do not disturb Today, Daily Routines, or Future ordering.

The Mac task row context menu adds `Plan to do -> Tomorrow`. Choosing it stores tomorrow as the task's date-only planned date. If the Tomorrow section is enabled, the action reveals that section; otherwise the task continues to appear through the existing Future path.

The preference is durable user-owned state stored with `RoutinaUserPreferences` so backup, import, reset, and defaults mirroring keep it consistent with the other task-list settings.

## Consequences

- The default Mac sidebar remains `Today` / `Future` unless the user enables the setting.
- With the setting enabled, the normal active task sections become `Today` / `Tomorrow` / `Future`.
- Calendar routines can appear in Tomorrow one day before their occurrence, matching the existing Today treatment for same-day calendar routines.
- iOS keeps its existing task-list section model.
