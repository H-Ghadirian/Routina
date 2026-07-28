# 0453: Use Context Menu Actions to Reorder Mac Home Sections

Date: 2026-07-28

Status: Accepted

Supersedes: [0451 Let Users Reorder Mac Home Sidebar Sections](superseded/0451-let-users-reorder-mac-home-sidebar-sections.md)

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0350 Add Optional Mac Tomorrow Task Section](0350-add-optional-mac-tomorrow-task-section.md), [0394 Add Custom Mac Sidebar Task Sections](0394-add-custom-mac-sidebar-task-sections.md), [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0450 Use Progressive Custom Section Management](0450-use-progressive-custom-section-management.md)

## Context

Decision 0451 exposed drag handles and section drop targets for persistent Mac
Home ordering. In practice, section dragging was unreliable and added another
drag payload, hover target, and transient state to a list that already supports
task dragging. The interaction complexity was not justified for a preference
that normally changes one position at a time.

The persistent stable-ID order remains useful. It can be edited more reliably
with native section-header context menu actions while retaining the same
presentation-boundary ordering and backup behavior.

## Decision

Mac Home does not expose section drag handles, section drag payloads, or section
drop targets.

Eligible durable section headers expose native `Move Up` and `Move Down`
commands in their right-click menu. A command moves the complete section by one
visible durable-section position, persists the stable-ID order, and is disabled
when that direction is unavailable.

`Today` and `Tomorrow` never expose either move command. Their other applicable
context-menu actions remain available. Pinned, custom, Future, and Archived
sections may expose the move commands; temporary search-only sections do not.

The stored order remains independent from task classification, planning,
custom-section catalog order, automatic rules, and task-row manual order.
Temporarily absent sections retain their stored preference, and newly available
sections still enter beside their canonical default neighbors.

## Consequences

- Section reordering uses a conventional, deterministic native Mac interaction.
- The task list no longer carries section-specific drag state or competes with
  task-row dragging.
- Boundary commands remain visible but disabled, so both available directions
  are discoverable without permitting invalid movement.
- Planning sections cannot be moved directly.
- Existing saved orders, backup/import behavior, and presentation caching remain
  compatible.
