# 0271: Use Probable Times for Assumed Planner Activity

## Status

Accepted

## Date

2026-06-22

## Refines

- [0005: Show Timeline Activity in the Day Planner](0005-show-timeline-activity-in-day-planner.md)
- [0094: Suggest Only Completed Activity in Planner Calendar](0094-suggest-only-completed-activity-in-planner-calendar.md)
- [0268: Show Assumed-Done Routines in Planner](0268-show-assumed-done-routines-in-planner.md)
- [0269: Support Planner Slot Actions](0269-support-planner-slot-actions.md)

## Refined by

- [0376: Hide Probable Time From Assumed-Done Forms](0376-hide-probable-time-from-assumed-done-forms.md)

## Context

Assumed-done routines are synthetic planner activity until the user confirms
them into history. Without a probable completion time, these synthetic cards
all land at the same default time, which makes daily routines such as meals
hard to review in Planner.

Automatic completed-activity suggestions also try to place themselves before
their completion timestamp. If task blocks or event blocks reserve the
available time, the suggestion can fail placement and disappear from the
timed grid, leaving the user with no direct way to drag it into a better slot.

## Decision

Eligible daily routines that have `Assume done` enabled store an optional
probable done time. Task creation and Task Detail editing expose that time
with a noon default. Assumed-done planner activity uses the routine's probable
time as its synthetic completion timestamp, while same-day confirmation history
continues to use the actual confirmation timestamp.

When an automatic completed-activity suggestion cannot be placed because
existing planner task or event blocks occupy the usable time, Planner shows it
in a top-of-day `Needs Time` lane for that day. The lane keeps the automatic
card's normal task-opening, confirm, hide, and drag behavior so the user can
drag the activity into the timed calendar manually.

Protected intervals such as Away, Focus, and Sleep remain a separate concern:
they can still suppress or link overlapping automatic activity instead of
turning it into a `Needs Time` card.

## Consequences

- Daily assumed-done routines can appear near their real-world expected time
  instead of clustering at noon.
- Users can recover and place automatic activity that has no valid timed-grid
  slot because the day is already reserved by planner tasks or events.
- The planner keeps completion history honest: probable times affect synthetic
  presentation, not persisted completion logs.
