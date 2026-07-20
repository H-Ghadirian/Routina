# 0385 Use Gentle Routine Cadence for Tracking

Status: Accepted

Date: 2026-07-13

Refines: [0177 Separate Interval and Calendar Repeat Controls](0177-separate-interval-and-calendar-repeat-controls.md), [0181 Allow Gentle Calendar Repeats](0181-allow-gentle-calendar-repeats.md), [0186 Put Item Runout in Repeat Type](0186-put-item-runout-in-repeat-type.md), [0200 Support Task Planned Dates](0200-support-task-planned-dates.md), [0382 Split Record Task Form Controls](0382-split-record-task-form-controls.md), [0383 Use Tracking as Record Label](0383-use-tracking-as-record-label.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md)

Refined by: [0396 Allow Quiet Tracking Cadence](0396-allow-quiet-tracking-cadence.md), [0397 Make Tracking Cadence Optional](0397-make-tracking-cadence-optional.md), [0400 Plan Tracking Rows Into Today](0400-plan-tracking-rows-into-today.md), [0408 Allow Explicit Planning for Daily Tracking](0408-allow-explicit-planning-for-daily-tracking.md)

## Context

Tracking entries started as unscheduled records with routine-like descriptive metadata but no repeat controls. That kept tracking away from due-date pressure, but it also prevented recurring time-analysis rows such as weekly reviews, recurring logs, or checklist runout tracking.

The desired model is closer to a routine whose due style is always Gentle: it can have cadence and routine-style options, but it should not become a Due/Overdue obligation.

## Decision

Tracking uses the internal `record` task type and keeps the user-facing `Tracking` label. Tracking schedule modes always report `Gentle` schedule behavior and the task form hides the `Due Style` picker for them.

Tracking exposes the same routine cadence controls: `Repeat type`, interval repeat, calendar repeat, and checklist `Item runout`. Standard tracking uses steps, checklist tracking can complete when every item is done, and item-runout tracking stores checklist item intervals in the same way runout routines do.

Tracking still omits due dates, exact reminders, and todo date availability. [0408 Allow Explicit Planning for Daily Tracking](0408-allow-explicit-planning-for-daily-tracking.md) later lets cadence-enabled Tracking store explicit planned dates regardless of daily cadence.

[0400 Plan Tracking Rows Into Today](0400-plan-tracking-rows-into-today.md) later refines this placement rule: explicit planned dates now place eligible Tracking rows into `Today` or enabled `Tomorrow`, while cadence-only Tracking stays in `Tracking`.

## Consequences

Tracking can model recurring analysis without becoming an overdue task.

Future Tracking changes should preserve the split between cadence and pressure: Tracking may repeat and nudge gently, but it should not expose a Due-style choice or become overdue unless a later decision explicitly changes that product model.
