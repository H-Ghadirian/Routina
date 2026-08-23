# 0644: Progressively reveal Mac Task Detail value options

## Status

Accepted

## Date

2026-08-23

## Refines

- [0188: Prefer self-explanatory UI over instructional copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0563: Present Importance and Urgency as independent task controls](0563-present-importance-and-urgency-as-independent-task-controls.md)
- [0642: Unify task configuration and retire legacy task-kind storage](0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md)

## Context

Mac Task Details showed every option for Importance, Urgency, Pressure, and
Thinking at the same time. The values were directly editable, but sixteen
simultaneous choices created more visual noise than the review surface needed.
Add and Edit also showed an unavailable `Changes over time` explanation for
one-time tasks even though that behavior can only apply to repeating work.

## Decision

- Mac Task Details keeps all four field names and current values visible in the
  shared Task Ladder values container.
- Each current value is a compact direct trigger. Selecting it horizontally
  reveals that field's complete segmented picker in place. Only one picker is
  open at a time, and choosing an option collapses it back to the new current
  value.
- At widths where all four controls fit, they keep a small fixed gap and use
  their intrinsic widths instead of being distributed into equal columns. An
  expanding picker keeps its leading position and pushes the controls after it
  to the right. The existing vertical fallback remains available when the
  complete row does not fit.
- Picker expansion is temporary view state, resets when another task opens, and
  is never persisted. Reduce Motion replaces the transition with an immediate
  state change.
- iOS Task Details keeps its existing compact picker presentation.
- Add and Edit omit `Changes over time` entirely for one-time tasks on both
  platforms. Repeating tasks continue to show the editor when eligible or the
  exact Behavior & Schedule requirement when not yet eligible.

## Consequences

- Task Details preserves the four-value mental model while emphasizing the
  person's choices instead of every alternative.
- Editing remains one click away and does not hide an entire field or introduce
  an aggregate Priority disclosure.
- Compact choices read as one related group instead of four controls spread
  across the full card, while expansion uses available horizontal space.
- One-time task forms no longer explain an inapplicable repeating-task feature.
- The compact and expanded controls keep full-surface hit targets and explicit
  accessibility labels.
