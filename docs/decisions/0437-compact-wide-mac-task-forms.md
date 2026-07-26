# 0437 Compact Wide Mac Task Forms

Status: Accepted

Date: 2026-07-26

Refines: [0180 Clarify Schedule Behavior Badge Preview](0180-clarify-schedule-behavior-summary.md), [0188 Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md), [0429 Keep Task List Visible Beside Mac Task Forms](0429-keep-task-list-visible-beside-mac-task-forms.md), [0431 Present One Progressive Recurrence Composer](0431-present-one-progressive-recurrence-composer.md)

## Context

Mac Add Task and Edit Task kept the task-list sidebar visible and presented one
progressive form, but the form cards still expanded across the complete detail
canvas. The Behavior card distributed a constrained settings column and a wide
preview column across that canvas, leaving large empty regions between related
controls.

The unified recurrence composer also forced desktop segmented controls to fill
rows of two or three items. A three-choice cadence therefore placed one choice
alone across an entire second row, while five frequency choices produced a
similarly uneven grid. These layouts made a wide desktop form feel less direct
than the compact interaction it represented.

## Decision

Full Mac task forms use a centered readable maximum width instead of stretching
cards to every available desktop pixel. The Behavior card uses bounded main and
support columns and relies on its content's intrinsic height rather than
reserving a mode-specific minimum height.

Routine schedule behavior, completion, and the task-list badge preview stay in
the same main configuration flow. Todo reminder and deadline controls may use a
secondary column when it fits and fall below the main controls when it does not.

The shared recurrence composer has distinct compact and desktop control
layouts:

- iOS keeps fill-width segmented controls with bounded row wrapping.
- macOS sizes recurrence segments to their labels and keeps them in one
  horizontal sequence when they fit.
- Desktop fixed schedule details and weekday targets use bounded readable
  widths.
- The visible `Repeat` section owns the recurrence hierarchy, so the composer
  does not repeat a second `Repeat behavior` heading above the cadence choices.

This changes presentation only. Recurrence draft state, validation, persistence,
occurrence generation, scheduling behavior, and save semantics remain
unchanged.

## Consequences

- Wide Mac windows keep task settings visually grouped instead of separating
  them with unused space.
- Cadence and frequency choices no longer create disproportionately wide
  partial rows on desktop.
- The badge preview appears near the Due/Gentle choice it explains.
- Narrow Mac forms and iOS continue to adapt without horizontal compression.
- Future desktop task-form controls should prefer intrinsic control width inside
  a bounded content measure unless the choice benefits from true full-width
  comparison.
