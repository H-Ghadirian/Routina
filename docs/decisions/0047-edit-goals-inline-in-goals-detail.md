# 0047: Edit Goals Inline in the Goals Detail Surface

- **Status:** Accepted
- **Date:** 2026-05-14

## Context

The Goals screen used a sheet for creating and editing goals. That forced users out of the main goal context, even though the goal detail screen already contains the goal overview, linked tasks, and linked goal hierarchy.

## Decision

Goal creation and editing should render inline in the Goals main/detail surface instead of in a separate sheet or popover.

- Creating a goal uses the main Goals content area.
- Editing a goal replaces that goal's detail content with the editor.
- macOS shows the editor in the split-view detail pane.
- iOS shows the editor inside the existing navigation stack.
- The shared `GoalsFeature.GoalDraft` remains the single source of truth for the editor, and saving selects the saved goal before refreshing the list.

## Consequences

Users keep spatial context while creating or editing goals. The editor can still share validation and persistence logic across iOS and macOS, but platform views decide where the shared form is displayed.
