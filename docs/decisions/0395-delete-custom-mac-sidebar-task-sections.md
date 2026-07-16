# 0395 Delete Custom Mac Sidebar Task Sections

Status: Accepted

Date: 2026-07-16

Refines: [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md)

## Context

Custom Mac sidebar sections are user-created organization buckets. Once a section has served its purpose, users need a direct way to remove it without editing defaults or moving every row first.

## Decision

Mac Home custom section headers expose a `Delete Section` context-menu action. Choosing it presents a destructive confirmation alert before any mutation.

Confirming deletion removes the section from the durable section catalog, clears that section assignment from any tasks using it, and removes the deleted section's manual-order key from affected tasks. Those tasks then fall back into the built-in `Today`, `Tracking`, `Tomorrow`, or `Future` presentation according to their own task data.

## Consequences

Custom sections can be cleaned up from the same surface where they appear. Deleting a section does not delete tasks, task history, tags, dates, or tracking metadata.
