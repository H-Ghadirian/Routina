# 0536: Match Mac Task Detail Overflow to Toolbar Chrome

Status: Accepted

Date: 2026-08-11

Refines: [0527 Keep Mac Task Detail Overflow Compact and Stateful](0527-keep-mac-task-detail-overflow-compact-and-stateful.md)

## Context

The bare idle vertical-overflow trigger read as an unexplained dark gap in the
Task Detail action cluster. When opened, its isolated blue circle then had more
visual weight than the neighboring link, edit, and close controls.

## Decision

Mac Task Detail keeps its compact native overflow menu and vertical `⋮` symbol,
but uses the same visible rounded toolbar chrome as every adjacent icon action
in both idle and active states. Opening the menu applies only a restrained
accent tint and border to that rounded control; it does not introduce a
separate circular surface.

Delete remains the final separated destructive menu item with its confirmation
dialog.

## Consequences

- The overflow control is discoverable before interaction instead of reading as
  empty toolbar space.
- The active state stays clear without competing with the primary Done action
  or neighboring icon controls.
- The action grouping and native macOS menu behavior from Decision 0521 remain
  unchanged.
