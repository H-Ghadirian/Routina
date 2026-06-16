# 0246 Show Multi-Day Ongoing Range

Status: Accepted

Date: 2026-06-15

Refines: [0199 Support Multi-Day Routine Start Flow](0199-support-multiday-routine-start-flow.md), [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)

## Context

Multi-day routines can be in progress across several calendar days, but the task detail calendar only showed created, done, today, and other lifecycle markers. A routine could say it was in progress since an earlier date without making that span visible in the calendar.

The task detail toolbar also relied on compact icon-bearing controls. For multi-day routines, an icon-only or completion-colored action makes it hard to tell whether the next action starts or stops the active span.

## Decision

Task detail calendars show an `Ongoing` range color from the routine's start day through today while a multi-day routine is in progress. Start and Stop use the currently selected calendar date in task details. When the user stops a multi-day routine, the calendar keeps a multi-day span marker across every day from the selected start day through the selected stop day.

The primary multi-day routine action reads `Start` before the routine starts and `Stop` while it is in progress. The macOS toolbar keeps the action text visible alongside the icon instead of allowing the control to collapse to an icon-only button.

## Consequences

The in-progress and completed multi-day spans become visible where the user already checks task history and recurrence context.

Stopping an in-progress multi-day routine still records the completion and clears the ongoing state. The start and stop timestamps are retained in task change history so the detail calendar can keep showing the completed span. Undoing that completion removes the matching span marker.
