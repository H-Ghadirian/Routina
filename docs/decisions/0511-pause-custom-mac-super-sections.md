# 0511 Pause Custom Mac Super Sections

Status: Accepted

Date: 2026-08-08

Refines: [0419 Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md), [0446 Edit Custom Section Paths in Mac Task Forms](0446-edit-custom-section-paths-in-mac-task-forms.md), [0450 Use Progressive Custom Section Management](0450-use-progressive-custom-section-management.md)

## Context

Pausing routines one by one is too slow when a whole area of work is inactive,
such as a project or season. Simply hiding a custom section would leave its
tasks overdue, scheduled, and eligible for automatic behavior, which is not a
real pause.

## Decision

Only a top-level custom section (a super section) can pause as a whole. Its
pause action applies Routina's existing task pause lifecycle to active tasks
explicitly assigned to that super section or one of its direct subsections, as
well as unpinned unassigned tasks currently routed into that super section by
its automatic tag rule. This cancels their notifications and suspends their
normal scheduling semantics without deleting assignments, ordering, or
subsection structure.

The durable super-section catalog stores the pause timestamp and the exact set
of task IDs paused by that action. Resuming the super section resumes only that
snapshot, preserving tasks that were already paused independently. Automatic
tag placement remains dynamic, but the rows it currently routes into the
section are captured at the time of the pause.

A paused super section remains visible in Mac Home with a `Paused` state and a
Resume Section command, even after all of its rows move to Archived. New task
creation and choosing a paused super section or its subsections as a task path
are unavailable until it is resumed. Settings continues to show the paused
state in the section summary.

## Consequences

- A broad inactive work area can be paused and restored with one action while
  preserving each task's ordinary individual lifecycle choice.
- Paused sections do not disappear, so resumption remains discoverable.
- Existing custom-section catalogs decode unchanged; pause metadata is
  additive and ignored by older payloads.
