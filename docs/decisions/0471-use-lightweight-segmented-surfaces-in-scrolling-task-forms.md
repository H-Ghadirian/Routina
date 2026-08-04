# 0471: Use Lightweight Segmented Surfaces in Scrolling Task Forms

## Status

Accepted

## Date

2026-08-04

## Refines

- [0419: Use Lightweight Surfaces Inside Unbounded Scroll Rows](0419-use-lightweight-surfaces-inside-unbounded-scroll-rows.md)
- [0462: Use a Compact Progressive iOS Task Editor](0462-use-a-compact-progressive-ios-task-editor.md)

## Context

The iOS Add Task and Edit Task forms use a native scrolling `Form`. Selecting
`Repeating` reveals Duration, Due Style, Completion, Repeat behavior, and
frequency controls together. Each segmented control previously owned a Liquid
Glass container and selected-segment glass effect, while the Due Style preview
added more glass badges.

Those individually useful effects multiplied backdrop and compositor work
during form scrolling. The one-time branch contained far fewer glass surfaces,
so the hitch appeared specifically after switching to Repeating. The form also
derived its available, visible, and hidden section collections several times in
one body evaluation.

## Decision

iOS Add Task and Edit Task set the shared segmented-control environment to a
scrolling surface style. In that style, segmented controls keep the same
layout, semantic tint, selection border, accessibility state, and complete hit
areas, but use lightweight shape fills instead of Liquid Glass backdrop
effects. Noninteractive schedule-preview badges inside the form use the same
lightweight scrolling-fill convention.

The default segmented-control surface remains Liquid Glass, so bounded and
non-task-form surfaces do not change. The task form computes one immutable
visible/hidden section presentation per body evaluation and shares it across
the `Form` builders.

## Consequences

- Revealing repeating controls no longer multiplies native glass backdrops in
  the scrolling task form.
- Add Task and Edit Task retain their compact progressive hierarchy and all
  existing recurrence behavior.
- New segmented controls added inside the iOS task form automatically inherit
  the lightweight scrolling surface.
- Other Routina segmented controls keep Liquid Glass unless their container
  deliberately opts into the scrolling style.
