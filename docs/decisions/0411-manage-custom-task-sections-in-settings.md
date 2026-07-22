# 0411 Manage Custom Task Sections in Settings

Status: Accepted

Date: 2026-07-20

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md), [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md), [0395 Delete Custom Mac Sidebar Task Sections](0395-delete-custom-mac-sidebar-task-sections.md), [0400 Plan Tracking Rows Into Today](0400-plan-tracking-rows-into-today.md), [0403 Rename Custom Mac Sidebar Task Sections](0403-rename-custom-mac-sidebar-task-sections.md), [0408 Allow Explicit Planning for Daily Tracking](0408-allow-explicit-planning-for-daily-tracking.md)

## Context

Custom Mac sidebar task sections began as row-context organization buckets. Users now need a central settings surface to create, rename, delete, and configure sections, plus a first step toward user-defined section placement rules. A common rule is tag-based routing, where rows carrying configured tags should appear in a named custom section.

The existing built-in `Today`, optional `Tomorrow`, `Tracking`, and `Future` sections remain useful while this capability is introduced. Removing those defaults is a separate product change.

## Decision

Mac Settings exposes a `Sections` page for managing custom task-list sections.

Each custom section keeps its stable section ID, title, creation date, optional color, and optional rule set in the durable custom-section catalog. Settings lets the user choose or reset that color, and Home uses it to tint the custom section surface and header. Sections without a color retain the neutral tint. The first supported automatic rules are:

- `Planned today`, which claims active unpinned tasks with an explicit stored planned date on the current day.
- `Planned tomorrow`, which claims active unpinned tasks with an explicit stored planned date on tomorrow.
- `Tracking entries`, which claims active unpinned Tracking rows.
- `Tags`, which claims active unpinned rows carrying any of the section's configured tag names using Routina's case- and accent-insensitive tag identity.

Manual section assignment remains stronger than rules. If a task is explicitly assigned to one custom section, another custom section's rule must not claim it. Within unassigned rows, custom sections still claim rows in catalog order before the built-in planning, tracking, and future fallback sections. Pinned and archived rows keep their existing priority.

Deleting a section from Settings removes the section catalog entry, clears that section's task assignments and manual-order key from affected tasks, and leaves the tasks themselves intact.

## Consequences

Users can manage custom sections from Settings without relying on row context menus.

Custom rules are additive: they can redirect matching rows into user-owned sections while the built-in Mac sidebar sections continue to exist as fallback surfaces.

The section catalog remains backward-compatible with existing saved custom sections that do not have rule or color metadata.
