# 0100: Reveal Task Form Details by Section

## Status

Accepted

## Date

2026-05-29

## Supersedes

[0058: Use Progressive Task Forms](0058-use-progressive-task-forms.md) for the optional-detail reveal mechanism only.

## Context

Task creation and editing used one More Details action to expose every optional section at once. That preserved progressive disclosure, but it made a focused action such as adding notes, tags, media, or a place feel like opening a large configuration surface.

Task detail already used compact Add More actions for some missing sections, but richer task details still routed through broad edit behavior rather than a section-specific choice.

## Decision

Task create and edit forms keep identity, scheduling, checklist, and populated optional sections visible by default. Empty optional sections are offered as individual Add Details buttons. Choosing one button reveals only that section and scrolls to it.

Task detail Add More actions should likewise prefer field-specific buttons. Inline controls may still reveal in place when the detail screen owns that interaction; richer metadata buttons open edit mode with the relevant form section revealed.

## Consequences

- The common task-capture flow stays compact without hiding advanced fields behind one all-or-nothing expansion.
- Users can add one specific detail without being dropped into every optional field.
- The macOS form navigator follows the same revealed-section state as the form content.
- Future optional task fields should add a section-specific reveal action instead of relying on a generic More Details expansion.
