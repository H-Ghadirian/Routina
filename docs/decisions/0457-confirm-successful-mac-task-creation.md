# 0457: Confirm Successful Mac Task Creation

## Status

Accepted

## Date

2026-07-29

## Refines

- [0076: Select Saved Home Items After Creation](0076-select-saved-home-items-after-creation.md)
- [0341: Consolidate Mac Home Toolbar Row](0341-consolidate-mac-home-toolbar-row.md)

## Context

Mac toolbar Quick Add showed a created-task toast, but the full Add Task form
closed after a successful save and relied only on the newly selected detail
screen to communicate success. That navigation preserved context but did not
make the completed save explicit. The existing toast also placed unused
fixed-width space after its close button, which looked like excessive trailing
padding.

## Decision

Every successful Mac task-creation path presents a transient confirmation with
the created task's name.

The full Add Task form continues to close, return to the task list, select the
new task, and show its details as required by Decision 0076. Its confirmation
does not offer an `Open details` action because those details are already
visible. Toolbar Quick Add keeps `Open details` because it preserves the
current workspace until the user chooses to navigate.

Created-task toasts place flexible width between their message and trailing
actions so the action and close controls remain aligned to the panel's standard
trailing inset.

## Consequences

- A successful full-form save has immediate, explicit feedback in addition to
  the selected detail screen.
- Canceling Add Task and failed or subscription-gated saves do not show a false
  success confirmation.
- Quick Add keeps its optional navigation action, while full Add Task avoids a
  redundant action.
- Toast controls no longer appear separated from the trailing edge by unused
  layout width.
