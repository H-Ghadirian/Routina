# 0394 Add Custom Mac Sidebar Task Sections

Status: Accepted

Date: 2026-07-16

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0285 Clarify Mac Sidebar Section Surfaces](0285-clarify-mac-sidebar-section-surfaces.md), [0384 Show Tracking as Mac Sidebar Section](0384-show-tracking-as-mac-sidebar-section.md), [0386 Match Tracking Inner Groups to Future](0386-match-tracking-inner-groups-to-future.md)

## Context

Mac Home has built-in top-level sidebar sections such as `Today`, `Tracking`, and `Future`. Those sections are useful defaults, but users also need named top-level places for their own work areas without turning those areas into tags, dates, or task types.

## Decision

Mac Home supports user-created custom top-level task sections. A row context menu can create a named custom section and move the selected task or tracking row into it, and existing custom sections appear as move destinations.

Custom sections are stored as a durable user preference catalog, while each task stores its assigned custom section ID. Assigned active unpinned rows are claimed into their custom section before `Tracking`, `Today`, `Tomorrow`, or `Future` can claim them, so each task still appears once per presentation. Pinned and archived rows keep their existing top-level priority.

Custom sections use their own manual-order keys and the same full-bleed Mac sidebar section surface style as `Today`, `Tracking`, and `Future`. Planning a custom-section row with `Plan to do` clears the custom-section assignment so planned work can move back into `Today` or `Tomorrow`.

## Consequences

Users can make named task-list areas without changing task type, dates, tags, or tracking semantics.

Backups include both custom section names and task assignments. Future custom-section management such as renaming or section reordering should preserve the stable custom-section IDs and manual-order keys.
