# 0183 Support Todo Availability Time and Windows

- Status: Accepted
- Date: 2026-06-07
- Refines: [0182 Show Todo All-day as Availability](0182-show-todo-all-day-as-availability.md), [0179 Make All-day an Availability Choice](0179-make-all-day-an-availability-choice.md)

## Context

[0182](0182-show-todo-all-day-as-availability.md) moved todo all-day into the Availability control but kept todo availability limited to `Any time` and `All-day`. That avoided exposing exact-time and window choices before the save model was ready to persist them for one-off tasks.

Users still need the same availability language for todos: a todo can be available any time, occupy an all-day block, become available at a specific time, or be available during a time window. Deadline remains a separate optional commitment.

## Decision

Todo forms use the full Availability set: `Any time`, `All-day`, `At time`, and `Window`.

For one-off todos, exact-time and window availability are stored in the task recurrence rule as a one-day interval with optional time metadata. The todo interval column remains normalized to one day, but the recurrence rule keeps the selected time or window.

All-day remains mutually exclusive with exact-time and window availability. Selecting all-day clears hidden exact-time and window flags for todos and routines.

Todo deadline and reminder controls stay separate from Availability. A todo can have availability timing without a deadline, and a deadline without availability timing.

## Consequences

- Availability has one meaning across routine and todo creation: when the item can show up or occupy time.
- Deadline remains about commitment, not whether the todo is all-day, at-time, or in a window.
- Save and edit flows must preserve one-off recurrence time metadata instead of normalizing all todos to an untimed one-day interval.
- Surfaces that only care whether an item is a one-off todo can keep using `scheduleMode == .oneOff`; surfaces that care about planner availability should read `recurrenceRule.timeOfDay` and `recurrenceRule.timeRange`.
