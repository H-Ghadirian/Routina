# 0427 Place Task Sidebar Location Below Detail Title

Status: Accepted

Date: 2026-07-25

Refines: [0420 Show Task Sidebar Location in Mac Details](0420-show-task-sidebar-location-in-mac-details.md)

## Context

Mac task details expose the selected task's live sidebar section path as a clickable breadcrumb. Placing that location after status and completion metadata separates it from the task identity and makes the detail hierarchy harder to scan.

## Decision

Mac task details place the sidebar section/subsection breadcrumb directly below the task title, before status, completion, calendar, tags, and other task metadata.

The breadcrumb keeps its existing live-presentation source and locate behavior.

## Consequences

The task's title and sidebar location read as one identity block, while all state and descriptive metadata follow them. Routine and one-time task detail headers use the same placement.
