# 0423: Separate Mac Task Title From Optional Media

## Status

Accepted

## Date

2026-07-24

## Refines

- [0058: Use Progressive Task Forms](0058-use-progressive-task-forms.md)
- [0100: Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md)
- [0353: Move Mac Task Form Actions Into Identity](0353-move-mac-task-form-actions-into-identity.md)

## Context

Mac Add Task and Edit Task placed the emoji chooser inside the always-visible Identity card beside the title. This made optional visual decoration look required during basic task capture. Image was already an optional section, but Emoji did not participate in the same section-specific progressive disclosure.

## Decision

Mac Add Task and Edit Task keep the Identity card focused on the task title, validation, title-derived metadata preview, and form actions. Emoji is a separate optional form section, parallel to Image, and both are available through `Add More Details`.

A newly created task's default emoji does not make the Emoji section appear automatically. In progressive Edit Task, an emoji that differs from the creation default counts as populated optional content and remains visible, consistent with the existing progressive-form rule for saved details.

## Consequences

- Basic Mac task capture starts with a simpler title-focused Identity card.
- Emoji and Image use the same section reveal, navigation, and ordering mechanisms as other optional details.
- Existing tasks with customized emoji keep that detail visible during editing.
- Cancel and Save remain in Identity, preserving the form-action ownership established by decision 0353.
