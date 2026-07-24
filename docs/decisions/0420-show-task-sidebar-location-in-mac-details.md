# 0420 Show Task Sidebar Location in Mac Details

Status: Accepted

Date: 2026-07-24

Refines: [0407 Locate Mac Task Detail Sidebar Row](0407-locate-mac-task-detail-sidebar-row.md), [0419 Nest Custom Subsections Under Super Sections](0419-nest-custom-subsections-under-super-sections.md)

## Context

The Mac task-detail locate shortcut can reveal a selected task in the left sidebar, but the detail screen does not show where the row currently belongs. A task's effective location may come from a custom assignment, a custom-section rule, planning, tracking, or built-in tag grouping, so its stored custom-section ID alone is not a complete source of truth.

## Decision

Mac task details show the selected task's current visible sidebar section path as a clickable breadcrumb. The path comes from the same current task-list presentation used to locate and render the sidebar row.

Clicking the breadcrumb reuses the existing locate action: it reveals task-list mode and the left sidebar, expands the containing top-level section and every collapsible nested group, selects the task, and scrolls its row into view. If filters or another presentation constraint remove the row, the breadcrumb is absent rather than presenting a stale location.

## Consequences

The breadcrumb remains accurate for both user-created super sections and subsections and built-in paths such as `Future` plus a tag group. Location display and navigation cannot drift from actual sidebar membership because both use the same presentation lookup.
