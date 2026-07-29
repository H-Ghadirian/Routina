# 0462: Use a Compact Progressive iOS Task Editor

## Status

Accepted

## Date

2026-07-29

## Refines

- [0058: Use Progressive Task Forms](0058-use-progressive-task-forms.md)
- [0100: Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md)
- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0264: Match Button Hit Areas to Visual Surfaces](0264-match-button-hit-areas-to-visual-surfaces.md)
- [0431: Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md)

## Context

The iOS Add Task and Edit Task form placed task type, routine duration, and
availability inside one Form section. Standalone dividers became full-height
Form rows, leaving unexplained blank space, while five time-availability
choices were squeezed into one segmented control and truncated on phone-width
screens.

The form also used one `More Details` switch that revealed every optional
section together. That made a focused action such as adding tags, notes, or an
estimate expand the entire advanced form, contrary to the section-specific
progressive disclosure established by Decision 0100.

## Decision

iOS Add Task and Edit Task use a compact grouped form with these rules:

- Task Type, Duration, and Availability are separate sections.
- Two-choice task type and duration controls remain immediate segments.
- Date and time availability use native navigation pickers so every option is
  readable at compact widths.
- The task-name field receives the strongest input emphasis in the form.
- Optional empty sections appear in an `Add details` menu. Choosing an item
  reveals only that section and scrolls it into view.
- Populated optional sections remain visible, and destructive Edit Task
  actions remain last.
- The Add details row uses the complete visible row as its touch target.

The redesign changes presentation and disclosure state only. Existing task
form bindings, validation, recurrence composition, persistence, and save
behavior remain authoritative.

## Consequences

- The common capture flow is shorter and no longer contains spacer rows or
  unreadable five-way segments.
- Advanced fields remain discoverable without flooding the form.
- Add Task and Edit Task share the same iOS presentation contract.
- New optional fields should join the targeted Add details menu unless they
  are essential or already populated.
