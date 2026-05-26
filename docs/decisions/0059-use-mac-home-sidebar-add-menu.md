# 0059: Use a Mac Home Sidebar Add Menu

## Status

Accepted

## Date

2026-05-26

## Context

Mac Home had separate creation entry points: the sidebar `+` opened the task form directly, while Goals mode also exposed a toolbar `+` for creating a goal. That made the sidebar `+` narrower than it appeared and duplicated goal creation chrome on the Goals surface.

## Decision

The Mac Home sidebar `+` opens an add menu with Goal and Task actions.

- Goal switches the Home split shell to Goals and opens the inline goal editor.
- Task opens the existing add-task form.
- Goals mode does not add a separate toolbar `+`; goal creation is routed through the shared sidebar add menu.

## Consequences

Creation actions stay grouped in one stable sidebar control. Goal creation continues to respect the inline editor decision, and the Goals detail toolbar remains focused on detail-specific actions.
