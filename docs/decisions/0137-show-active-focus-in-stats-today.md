# 0137: Show Active Focus in Stats Today

## Status

Accepted

## Date

2026-06-02

## Context

Stats focus charts originally counted completed task and unassigned focus sessions by completion day. That kept historical focus totals stable, but it made the current day look too low while a focus timer was still running. Stats also did not load board focus session records, while the Today Focus widget includes task, unassigned, and board focus. Stats and the widget could therefore disagree during an active session or whenever today's focus included board work.

## Decision

Stats focus duration points include task, unassigned, and board focus sessions. Active task, unassigned, and board sessions contribute to the current reference day. Completed task and unassigned sessions continue to be bucketed by completion day before optional week or month grouping; completed board sessions are bucketed by stop day. Active sessions contribute only their focused current-day duration up to the Stats reference time; paused active sessions stop incrementing at their paused time, and abandoned task focus sessions remain excluded. Stats screens refresh their data snapshot periodically while an unpaused focus session is active so live current-day totals do not go stale while the screen remains open.

## Consequences

- The Focus time chart and selected-day detail agree with the live Today Focus widget while task, unassigned, or board focus is active.
- Board focus appears in focus contributions by sprint title when available, otherwise as "Board focus".
- Stats refreshes the live focus total only while an unpaused active focus session exists; paused or idle screens do not keep a timer running.
- Historical completed focus totals keep their existing completion-day semantics.
- Cross-midnight active focus is treated as a practical current-day span, with the same aggregate-pause limitation noted for the Today Focus widget.
