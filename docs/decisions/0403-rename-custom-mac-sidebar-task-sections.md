# 0403 Rename Custom Mac Sidebar Task Sections

Status: Accepted

Date: 2026-07-18

Refines: [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md), [0395 Delete Custom Mac Sidebar Task Sections](0395-delete-custom-mac-sidebar-task-sections.md)

## Context

Mac Home custom sections are durable user-owned organization buckets. Users can already create them from task row context menus and delete them from section-header context menus, but correcting or evolving a section name required deleting and recreating the bucket.

Deleting and recreating is unnecessarily disruptive because tasks store assignments and manual ordering by stable custom section ID.

## Decision

Mac Home custom section headers expose a `Rename Section` context-menu action. Choosing it presents a small rename prompt seeded with the current title.

Saving a rename updates only the section catalog title for the existing section ID. The section ID, task assignments, collapse state, and manual-order keys remain unchanged. Empty titles and titles that normalize to another custom section's title are rejected.

## Consequences

Users can revise custom sidebar section names without moving tasks or losing section ordering.

Custom section titles remain unique for clear move-menu destinations, while section identity continues to be based on durable UUIDs rather than visible names.
