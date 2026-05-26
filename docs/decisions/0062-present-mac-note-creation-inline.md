# 0062: Present Mac Note Creation Inline

## Status

Accepted

## Date

2026-05-26

## Context

The Mac Home sidebar add menu creates notes, goals, and tasks. Goal and task creation use the main app surface, while note creation was still presented as a sheet. That made notes feel modal and separate from the rest of Home creation.

## Decision

On macOS, Add Note opens the standalone note editor in the Home detail area instead of a sheet. Canceling or saving closes the inline editor and returns the detail area to the normal Home selection surface.

The shared note editor keeps sheet-friendly defaults for other call sites, but accepts optional cancel/save callbacks so a host can own inline dismissal.

## Consequences

- Mac note creation is visually aligned with the existing Add Goal and Add Task workflows.
- The note editor remains reusable in modal contexts where a sheet is still appropriate.
- Future Mac Home creation surfaces should prefer the detail area for primary creation flows instead of introducing separate popups.
