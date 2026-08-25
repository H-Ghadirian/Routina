# 0662: Reserve the First Mac Task-Row Line for the Title

## Status

Accepted

## Date

2026-08-25

## Refines

- [0038: Configure Home Task Row Fields](0038-configure-home-task-row-fields.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0452: Label Date-Planned Tasks in Their Ordinary Section](0452-label-date-planned-tasks-in-their-ordinary-section.md)
- [0636: Replace Configurable Flags With Built-In Behaviors](0636-replace-configurable-flags-with-built-in-behaviors.md)

## Context

The Mac main task list placed the lifecycle Status Badge at the trailing end of
the title line. In a constrained sidebar, that badge shortened the only space
available for the task name even though Tags and `Planned today` already used a
secondary line. Assigned behavior Flags were available in the row's cached task
display but were not visible in the task list.

The title is the primary identifier people scan. Status, organizational Tags,
behavior Flags, planning context, and linked Goals are secondary labels that can
share a separate visual tier without making the row ambiguous.

## Decision

Mac main task-list rows reserve their first content line for the task title.
The next line owns the row's visible secondary labels: `Planned today`, Tags,
assigned Flags, linked Goals, and the lifecycle Status Badge. The status remains
at the trailing edge of that secondary line; the other labels remain leading.
The secondary line is omitted when none of those fields is visible or present.

Schedule, progress, pressure, step, checklist, and place text follows the label
line when its existing appearance fields make it visible. Flags become a
separate Mac Task Row appearance field, visible by default like other newly
introduced row fields. iOS row presentation is unchanged.

Rows consume the Tags, Flags, Goals, planning-label membership, and effective
status already present in the Home display and task-list presentation snapshots.
They do not fetch, filter, or walk task collections while rendering.

## Consequences

- Long task names receive the full content width before truncation.
- Status no longer competes with the title, while remaining visible at a
  predictable trailing position directly beneath it.
- Tags and behavior-bearing Flags remain visually distinct, and people can hide
  either category independently through Task List -> Appearance.
- Rows with no secondary labels do not gain an empty spacer line.
- Adding label categories does not introduce whole-list work into scrolling.
