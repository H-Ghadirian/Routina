# 0646 — Compact Mac Changes-over-Time Editing

Date: 2026-08-23

Status: Accepted

## Context

The Mac Changes over time editor required a person to enable the feature, choose
one shared timing mode, enable each affected metric separately, select its
target, and decode a four-row preview. Those controls represented a small rule
accurately, but they spread one decision across redundant enablement controls
and a large explanation surface.

The stored model already has the simpler shape the interface should express:
one shared curve and lead window, plus an optional higher target for Importance,
Urgency, and Pressure. A missing target already means that metric does not
change, and a rule with no targets is not persisted.

## Decision

- macOS presents one compact row for each supported metric. Every row shows its
  Base value and one target menu containing `No change` plus valid higher values.
- The editor has no global enable toggle and no per-metric checkbox. Choosing the
  first higher target activates the rule; returning every target to `No change`
  removes it.
- Once at least one target exists, one shared menu chooses `On due date` or
  `Gradually`. The gradual choice reveals the existing lead-day stepper with a
  short native transition that respects Reduce Motion.
- macOS replaces the four-state preview with one live sentence summarizing the
  timing and changed Base-to-target pairs, followed by a quiet note that changed
  values remain until completion and then reset.
- iOS retains its existing editor and four-state preview. The persistence,
  derivation, eligibility, Task Detail summary, and Task Ladder Base/Now behavior
  remain unchanged.

## Consequences

- The Mac editor communicates the stored rule directly and removes two layers of
  checkbox state.
- `No change` is visible as an ordinary choice instead of being encoded by a
  disabled target picker.
- Timing appears only when it can affect at least one metric, reducing inactive
  controls without hiding any saved behavior.
- The compact summary preserves the due-date, gradual-window, target,
  persistence, and reset meaning without repeating every lifecycle state as a
  separate row.

## Revises

- Revises the macOS preview and editor presentation required by
  [0642](0642-unify-task-configuration-and-retire-legacy-task-kind-storage.md).
- Refines the configuration surface introduced by
  [0604](0604-expose-time-based-ladder-values-in-task-forms-and-details.md).
- Preserves the shared curve and independent target model from
  [0592](0592-derive-time-based-task-ladder-values-from-repeating-due-dates.md).
