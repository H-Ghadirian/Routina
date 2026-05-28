# Drag Tasks to the Planner All Day Lane

## Status

Accepted

## Date

2026-05-28

## Context

Planner users can mark tasks as all-day data, and completed routine activity can appear in the planner as an automatic timed suggestion. That left an awkward gap for past completed routines and other all-day work: hiding a timed suggestion removed it from the planner presentation, but it was not a move into the All Day lane.

The planner should treat the All Day lane as an Apple-style calendar destination rather than as a passive display-only area.

## Decision

The planner All Day lane accepts drag and drop for task payloads, persisted timed planner blocks, and automatic completed-activity suggestion blocks.

Dropped tasks are marked `isAllDay` as first-class task data. Dropped one-off tasks also move their deadline date to the target day. Dropped timed planner blocks mark the task all-day and remove the timed planner placement so the same work does not appear twice.

Completed activity for all-day tasks renders as a one-day All Day block on the activity date, and automatic timed planner suggestions exclude all-day tasks.

## Consequences

Users can move a completed routine suggestion to the All Day lane by dragging it there instead of hiding it from the planner.

All-day display remains derived from task data and timeline evidence, not from a separate custom all-day planner block model.

Task recurrence still owns routine occurrence dates. Dropping a routine into the All Day lane does not rewrite its recurrence pattern.
