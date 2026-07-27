# 0052 — Stage locate scrolling through lazy ancestors

Date: 2026-07-27

## Symptom

Clicking a Task Detail sidebar-path breadcrumb could expand `Future` but stop at its header instead of scrolling to the selected row inside a later tag subsection such as `#Travel`.

## Root Cause

The locate request carried only the top-level section anchor. The task row lived inside nested lazy stacks, so an off-screen tag or task-kind group had not necessarily been materialized when `scrollTo(taskID)` ran. The unresolved row scroll was discarded, leaving the successful preparatory scroll at the `Future` header. Animated ancestor expansion also raced the attempts to resolve the row.

## Fix

Locate requests now carry the complete section and group path. The task list installs stable scroll anchors on parent and child groups, expands the path without animation, and stages scrolling through each lazy ancestor before targeting and confirming the task row.

## Prevention Rule

When programmatic navigation targets content inside nested lazy containers, carry and visit every lazy ancestor anchor before scrolling to the leaf identity; logical visibility alone does not mean the leaf view has been materialized.

## Regression Safeguard

Focused scroll-policy tests require a located task's scroll plan to visit its section, parent group, child group, and row in order. The Mac source regression check requires anchors on both group levels, and the task-list scenario records the expected final viewport.
