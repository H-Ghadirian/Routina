# 0429: Keep Task List Visible Beside Mac Task Forms

## Status

Accepted

## Date

2026-07-26

## Refines

- [0100: Reveal Task Form Details by Section](0100-reveal-task-form-details-by-section.md)
- [0311: Move Mac Home Mode Strip to Toolbar](0311-move-mac-home-mode-strip-to-toolbar.md)

## Context

Mac Add Task and Edit Task replaced the left task list with a second navigation
surface containing clickable form-section titles. The form already presents its
sections in one progressive scroll surface, reveals optional sections through
`Add More Details`, and scrolls newly revealed content into view. Replacing the
task list removed useful task context while duplicating navigation inside the
form.

## Decision

Mac Add Task and Edit Task keep the normal task-list sidebar visible. The task
form remains responsible for its own progressive disclosure, section ordering,
and scrolling. Mac no longer presents a separate form-section navigator in the
Home sidebar.

## Consequences

- Users retain surrounding task context while creating or editing a task.
- The sidebar continues to expose the active task-list mode and filter summary.
- Form-section reveal and scroll behavior remains available inside the form.
- The sidebar-only section navigator and its drag state are removed.
