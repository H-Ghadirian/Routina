# 0174: Do Not Restore Mac Add Task Composer

## Status

Accepted

## Date

2026-06-07

Refines [0074](0074-parse-mac-add-task-title.md) for Mac task creation and [0076](0076-select-saved-home-items-after-creation.md) for Home navigation after creation.

## Context

Mac Home persists temporary sidebar selections so the app can reopen to useful workspaces such as routines, timeline, stats, and settings. The Add Task composer is different: it is an in-progress capture surface backed by transient form state.

Restoring the Add Task sidebar mode after relaunch can reopen the form navigator without the matching add form state, leaving Home in a half-open creation surface.

## Decision

Mac Home treats Add Task as a transient sidebar mode. Users can still enter Add Task during the current session, but temporary view-state persistence normalizes Add Task to Routines before saving or restoring launch state.

## Consequences

- Relaunching after opening Add Task returns to the normal routines sidebar instead of a stale form navigator.
- Existing saved temporary state that already contains Add Task is repaired on next launch.
- Durable workspace restoration remains available for non-transient Home modes.
