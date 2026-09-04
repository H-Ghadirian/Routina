# 0733: Distinguish Mac Task Ladder Row Kinds Visually

## Status

Accepted

## Date

2026-09-04

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0571: Show Task Identity Metadata in the Mac Task Ladder](0571-show-task-identity-metadata-in-mac-task-ladder.md)
- [0574: Separate Task Ladder Placement From Completion](0574-separate-task-ladder-placement-from-completion.md)
- [0722: Move Mac Task Ladder Controls to the Right Sidebar](0722-move-mac-task-ladder-controls-to-the-right-sidebar.md)

## Context

Mac Task Ladder rows distinguished a container-only group and a repeating task
used as a group with `Group` and `Task group` badges. A person had to read those
repeated labels to understand the row structure, and the badges competed with
meaningful state such as inheritance, recurrence, and child count.

## Decision

- Container-only groups use a folder-shaped leading identity that retains the
  group's emoji.
- Repeating tasks enabled as Task Ladder groups use stacked rounded tiles around
  their task emoji.
- Ordinary tasks keep one rounded emoji tile.
- Container-group and task-group identity icons are structural and remain
  visible when the optional Task Ladder `Icon` appearance field is off.
  Ordinary task icons continue to follow that preference.
- Group and task-group titles use semibold weight. Ordinary task titles retain
  their regular weight except while selected.
- Visible `Group` and `Task group` type badges are removed. Inherited state,
  recurrence, child count, and other independently meaningful row context remain
  available under their existing rules.
- The three leading identities retain explicit accessibility labels so the
  distinction does not depend on interpreting shape or color.

## Consequences

- People can distinguish container groups, task groups, and ordinary tasks by
  shape and hierarchy before reading secondary metadata.
- Removing repeated type badges leaves more horizontal space for state, Tags,
  Flags, and other chosen context.
- Color supports the shapes but is not the only differentiator.
