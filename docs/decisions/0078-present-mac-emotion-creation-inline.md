# 0078: Present Mac Emotion Creation Inline

## Status

Accepted

## Date

2026-05-27

## Context

The Mac Home add menu can create tasks, goals, notes, and emotion logs. Tasks, goals, and notes use the main Home detail area for primary creation, while emotion logging was still presented as a sheet. That made emotion capture feel separate from the other creation flows.

## Decision

On macOS, Add Emotion opens the standalone emotion editor in the Home detail area instead of a sheet. Canceling closes the inline editor. Saving closes the editor and routes to the saved emotion entry in Timeline with the Emotions filter active.

The shared emotion editor keeps sheet-friendly defaults for iOS and other modal call sites, but accepts optional cancel/save callbacks so a host can own inline dismissal.

## Consequences

- Mac emotion capture aligns with Add Task, Add Goal, and Add Note creation.
- Saved emotion logs remain easy to review immediately through the existing Timeline detail surface.
- Future Mac Home creation surfaces should continue to prefer the detail area for primary capture flows.
