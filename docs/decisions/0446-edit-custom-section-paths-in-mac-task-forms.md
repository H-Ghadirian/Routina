# 0446: Edit Custom Section Paths in Mac Task Forms

Status: Accepted

Date: 2026-07-28

Refines: [0058 Use Progressive Task Forms](0058-use-progressive-task-forms.md), [0419 Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md), [0429 Keep Task List Visible Beside Mac Task Forms](0429-keep-task-list-visible-beside-mac-task-forms.md)

Refined by: [0456 Show Resolved Automatic Paths in Edit Task](0456-show-resolved-automatic-paths-in-edit-task.md)

## Context

Mac users can move an existing task into a custom super section or subsection
from the task row, but task creation and editing do not expose that assignment.
Creating a task while focused on a custom sidebar section also loses the
section context when the Add Task form opens.

## Decision

Mac custom super-section and subsection headers expose `New Task`. That action
opens the full Add Task form with the clicked section selected.

Add Task and Edit Task keep a visible `Path` control in the Identity card. The
control shows the selected super-section/subsection breadcrumb and edits the
task's existing durable custom-section ID. `Default` clears the explicit custom
assignment and lets normal sidebar placement rules choose the task's ordinary
section.

The selected path participates in creation-draft restoration, save-change
detection, task creation, and task editing. A section explicitly chosen by a
sidebar `New Task` action takes precedence over a restored creation-draft path.
If a selected catalog entry no longer exists, the form clears the stale
assignment.

## Consequences

- Users can create a task directly inside the sidebar hierarchy and verify its
  destination before saving.
- Add and Edit use the same one-level hierarchy and stored section ID as row
  `Move to`; no task-model migration or parallel path representation is added.
- Built-in planning projections such as Today and Tomorrow remain separate from
  this organizational path.
