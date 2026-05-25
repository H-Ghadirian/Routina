# 0058: Use Progressive Task Forms

## Status

Accepted

## Date

2026-05-25

## Context

Task creation and task editing exposed most of Routina's task fields at once. The form supported advanced task metadata, but showing empty optional controls for notes, tags, goals, linked tasks, media, estimation, priority, places, and recurrence made the common "capture a task" flow feel more complex than the user's intent.

Task detail had a related problem: empty optional sections such as comments and linked tasks were visible even when there was no content yet.

## Decision

Task forms use progressive disclosure by default for create and edit flows. The collapsed form keeps identity and scheduling controls visible, plus any optional sections that already contain user-entered content. Optional fields remain available behind More Details.

Task detail hides empty optional sections and offers compact Add More actions for adding comments, linked tasks, or richer details.

## Consequences

- Creating a task remains valid with only a name.
- Advanced metadata stays available without making the default flow feel like a long configuration checklist.
- macOS form navigation mirrors the same progressive visibility as the form content.
- Future task fields should default to the More Details area unless they are essential to task capture or already contain content.
