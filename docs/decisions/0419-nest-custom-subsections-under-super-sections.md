# 0419 Nest Custom Subsections Under Super Sections

Status: Accepted

Date: 2026-07-23

Refines: [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md), [0395 Delete Custom Mac Sidebar Task Sections](0395-delete-custom-mac-sidebar-task-sections.md), [0403 Rename Custom Mac Sidebar Task Sections](0403-rename-custom-mac-sidebar-task-sections.md), [0411 Manage Custom Task Sections in Settings](0411-manage-custom-task-sections-in-settings.md)

Refined by: [0450 Use Progressive Custom Section Management](0450-use-progressive-custom-section-management.md)

## Context

Custom task sections were flat top-level buckets. Users need one additional organization level so a broad area can contain smaller task buckets without introducing recursive trees or using tags as a substitute.

## Decision

User-created top-level custom sections are super sections. Each super section can contain user-created subsections one level below it. Deeper nesting is not supported.

The durable custom-section catalog remains flat and backward-compatible. Each subsection has its own stable section ID and stores the ID of its parent super section; existing catalog entries without a parent remain top-level super sections. Tasks continue storing one custom-section ID, which may identify either a super section or a subsection, so no task-model migration is required.

Mac Settings manages super sections and their subsections. A super-section header can also create a subsection. Task-row `Move to` menus show super sections hierarchically and let a row move either directly into a super section or into one of its subsections.

The sidebar renders subsection rows as collapsible nested groups inside their super section. Manual ordering uses the assigned section or subsection's stable key. Deleting a subsection clears its assignments and ordering; deleting a super section cascades through its subsections while leaving the tasks intact.

Automatic section rules and color continue to belong to super sections. Subsections are manual organization buckets.

## Consequences

Existing custom-section catalogs and task assignments decode unchanged as super-section data.

The hierarchy is intentionally capped at two levels, keeping presentation, deletion, backup, and move semantics deterministic.
