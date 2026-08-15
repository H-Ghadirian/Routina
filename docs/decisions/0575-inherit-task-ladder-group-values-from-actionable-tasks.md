# 0575: Inherit Task Ladder Group Values From Actionable Tasks

## Status

Accepted

## Date

2026-08-15

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0561: Add a Separate Mac Task-Ranking Ladder](0561-add-separate-mac-task-ranking-ladder.md)
- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)

## Context

A container-only group may represent a changing set of obligations. Requiring a
person to update both every child and the group's Pressure, Urgency, Importance,
or Thinking needed duplicates work and lets the root ladder become stale. A
Company group with one High-pressure actionable ticket should be able to appear
under High pressure without copying that value into permanent group metadata.

The inherited result must remain understandable and must use the same
availability rules as the nested Task Ladder. Completed, blocked, archived, or
otherwise Ladder-hidden work should not keep a group artificially elevated.

## Decision

Each categorical Task Ladder group metric independently supports three kinds of
selection: `Inherit`, `No value`, or an explicit value. Existing groups and new
groups continue to use their stored choice until the person selects `Inherit`.

For an inherited metric, the group's effective root value is the highest
explicit value among its currently actionable direct child tasks. Tasks already
excluded from Task Ladder do not contribute. Missing child values are ignored;
if no eligible direct child has an explicit value, the group remains in that
metric's `No value` section. Estimated time remains read-only and groups do not
inherit an estimate.

Inheritance is stored with the synchronized Task Ladder organization, while the
effective value is derived only when the immutable ranking presentation is
rebuilt. The group row labels inherited values. Reordering an inherited group
inside its current value section preserves inheritance. Deliberately moving it
across a value-section boundary changes that metric to the destination's
explicit value and turns inheritance off.

## Consequences

- A group's root position follows relevant changes to its actionable tasks
  without mutating either the group or its children.
- Different group fields can mix inherited, missing, and explicit choices.
- A blocked, completed, archived, paused, snoozed, canceled, or Flag-hidden task
  cannot determine the group's effective value while it is absent from Task
  Ladder.
- Existing synchronized group data decodes with inheritance off because the new
  stored field is optional.
- Direct-child aggregation matches the group's visible nested membership and
  avoids recursively assigning a value from hidden deeper descendants.
