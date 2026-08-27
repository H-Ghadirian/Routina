# 0603: Start Mac Focus From One Recalling Sheet

## Status

Accepted

## Date

2026-08-17

## Revises

- The duration-first presentation in [0244: Start Mac Toolbar Focus With Task Picker](0244-start-mac-toolbar-focus-with-task-picker.md)
- The retained duration-first behavior in [0333: Move Mac Focus Control to Planner Calendar Header](superseded/0333-move-mac-focus-control-to-planner-calendar-header.md)

## Refines

- [0267: Support Mac Toolbar Tag Focus](0267-support-mac-toolbar-tag-focus.md)

## Revised By

- [0681: Move Mac Focus Into the New Menu](0681-move-mac-focus-into-new-menu.md) moves the unchanged recalling sheet behind the global `+` action menu.

## Context

The Mac Planner Focus control presented a small duration menu and then opened a
separate task-and-tag picker sheet. Starting one session therefore required two
transient presentation layers even though duration and work attribution are one
choice. The sheet also opened without restoring the person's last attributed
Focus choice, making repeated sessions unnecessarily repetitive.

## Decision

Pressing the Mac Focus action opens the Focus picker sheet directly.
The sheet owns the count-up and fixed-duration choices alongside task search,
tag filtering, task starts, and tag starts.

The sheet initializes its duration from the most recently started attributed
task or tag Focus session. If that session used a custom fixed duration, the
sheet keeps that duration available beside the standard choices. Unassigned
Plan or Watch Focus does not replace this default because it is not a choice
made through the attributed Focus flow. With no attributed history, the sheet
defaults to 25 minutes.

If the latest attributed session was tag-backed and that tag is still available
on an active task, the sheet also preselects the tag. For example, a previous
count-up `#HSE` session reopens as `Count up · #HSE` and can be repeated with the
sheet's Start action. A removed tag is not restored as a hidden selection. A
previous task-backed session restores its duration but does not silently select
or start a task; task rows remain explicit start actions.

## Consequences

- Mac Focus starts use one sheet instead of a menu followed by a sheet.
- Duration and attribution can be reviewed and changed together before start.
- Repeating a recent tag Focus takes one Focus click and one Start click.
- Existing Focus session storage, task/tag attribution, Planner evidence,
  blocking, pause/resume, and history behavior remain unchanged.
