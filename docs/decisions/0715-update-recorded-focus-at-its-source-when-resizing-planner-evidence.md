# 0715 — Update recorded Focus at its source when resizing Planner evidence

Status: Accepted

Date: 2026-09-03

Refines:

- [0600: Edit Recorded Tag Focus From Mac Planner](0600-edit-recorded-tag-focus-from-mac-planner.md)
- [0651: Keep Task Focus Separate From Actual Time](0651-keep-task-focus-separate-from-actual-time.md)
- [0691: Split Focus Activity Across Local Days](0691-split-focus-activity-across-local-days.md)

## Context

A completed Focus session and its Calendar rectangle are stored separately: the
`FocusSession` is the authoritative history used by Task Details, Timeline, and
Stats, while persisted Planner blocks are its Calendar evidence. Mac Calendar
allowed those rectangles to be resized through the ordinary Planner-block
gesture, but the gesture changed only the evidence. Task Details therefore kept
the old Focus total, and returning from Backlog recreated the old rectangle when
Focus reconciliation projected the unchanged session again.

## Decision

When a resize begins on completed task- or tag-Focus evidence, Planner remembers
the owning Focus session and every persisted block belonging to that session. At
the end of the gesture, it commits the rectangle's start and duration to the
`FocusSession`, replaces the old Planner evidence with evidence rebuilt from the
updated session, saves both, and publishes the normal routine update.

A deliberate resize of Focus evidence has the same correction semantics as the
existing recorded-Focus editor: paused or multi-day segments are replaced by one
continuous interval represented by the resized rectangle. The Focus session and
all of its affected day blocks participate in one Planner Undo/Redo change.

Ordinary planned task blocks keep their existing independent placement behavior.
Updating Focus duration remains separate from Actual time and does not modify a
task or routine completion's recorded duration.

## Consequences

- Task Details updates its Focus total and session duration immediately after the
  resize finishes.
- Switching to Backlog and returning to Planner cannot restore the old rectangle,
  because the authoritative Focus session now contains the edited interval.
- Undo and Redo restore the Focus session and every affected Calendar block
  together instead of recreating another source/projection mismatch.
- Editing completed task Focus from its history control uses the same shared
  source-and-evidence mutation path.
