# 0456: Show Resolved Automatic Paths in Edit Task

Status: Accepted

Date: 2026-07-29

Refines: [0420 Show Task Sidebar Location in Mac Details](0420-show-task-sidebar-location-in-mac-details.md), [0446 Edit Custom Section Paths in Mac Task Forms](0446-edit-custom-section-paths-in-mac-task-forms.md)

## Context

Task Details shows a task's resolved location from the live Mac sidebar
presentation. Edit Task previously showed `Default` whenever the task had no
explicit custom-section ID, even when automatic tag rules or built-in placement
put the task in a known section. The two adjacent surfaces therefore appeared
to disagree about the same task.

## Decision

Edit Task reuses the live Task Details sidebar breadcrumb while the task has no
explicit custom-section assignment. The Path control displays that breadcrumb
with `(Automatic)` so the resolved location is visible without implying that a
custom-section ID is stored.

An explicit custom super-section or subsection assignment continues to take
precedence and displays without the automatic suffix. Choosing `Automatic`
clears the explicit assignment. If no resolved sidebar location is available,
the control displays `Automatic` by itself. Add Task also uses `Automatic`
instead of the ambiguous `Default` label.

## Consequences

- Task Details and Edit Task describe the same currently resolved sidebar
  location for automatically placed tasks.
- Displaying an automatic location does not persist it as a manual custom
  assignment.
- Explicit custom destinations remain editable through the existing durable
  section ID and continue to override automatic rules.
- Clearing an explicit path can show `Automatic` without predicting a new
  resolved path until the saved task returns to the live sidebar presentation.
