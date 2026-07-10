# 0366: Keep Mac Task Detail Add More Inline

Date: 2026-07-10

Status: Accepted

Refines: [0100 Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md), [0335 Move Mac Task Detail Actions Into Detail Content](0335-move-mac-task-detail-actions-into-detail-content.md)

## Context

Task Detail already used field-specific `Add more details` actions, but the actions behaved inconsistently on Mac. Detail-owned controls such as comments, time, pressure, state, and checklist stayed on the task detail screen, while richer metadata such as tags, goals, places, notes, links, color, media, and files switched the whole surface into Edit Task with the requested form section revealed.

That preserved reuse of the task form controls, but it interrupted the detail-reading workflow. The user expectation for the Add More section is that selecting a button adds that detail section to Task Details rather than navigating away to the full edit surface.

## Decision

Full Mac Task Details keeps `Add more details` actions in the task detail screen whenever the requested field can be edited there. Existing detail-owned controls continue to reveal in place. Form-backed metadata actions prepare the normal edit draft and show only the selected form section card inline inside Task Details, with local Cancel and Save controls that use the shared edit save path.

This inline behavior covers Estimate, Tags, Goals, Events, Linked Task, Places, Notes, Links, Color, Image, Voice Note, and File. The normal full Edit Task button remains available for broad task edits.

## Consequences

- Add More actions have a consistent stay-in-details interaction on Mac.
- Metadata editing continues to reuse the central task form controls and save builder instead of duplicating persistence logic.
- The detail page can reveal multiple form-backed sections before one save, so the shared edit draft is prepared once for that inline edit session.
- Future Mac Task Detail optional metadata should prefer inline detail cards before introducing a route to full edit mode.
