# 0068: Select Mac Sidebar Rows for Deep Links

## Status

Accepted

## Date

2026-05-26

## Supersedes

- The macOS tab-routing portion of [0061: Share Stable Routina Deep Links](0061-share-stable-routina-deep-links.md)

## Context

Routina's macOS Home screen owns the working sidebar for tasks, goals, timeline notes, and other timeline entries. Deep links could open the correct detail, but goal and note links routed to the standalone Goals or Timeline tabs, leaving the Home sidebar without a selected row for the opened entity.

## Decision

On macOS, task, goal, and note deep links open the Home tab and synchronize the Home sidebar with the target entity. Task links select the task row in the routines/todos sidebar, goal links switch Home to Goals mode and select the goal, and note links switch Home to Timeline mode, clear timeline filters to Notes, and select the note row.

iOS continues using its platform tab/sidebar behavior from the shared deep-link model.

## Consequences

- Opening a macOS entity link shows both the detail and the matching selected row in the left sidebar.
- Goal and note deep links share the same in-app sidebar presentation as manually choosing those Home modes.
- Future macOS entity links should update the visible sidebar selection together with the detail route.
