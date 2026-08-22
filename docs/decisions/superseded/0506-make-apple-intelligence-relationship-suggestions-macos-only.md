# 0506: Make Apple Intelligence Relationship Suggestions macOS-Only

## Status

Superseded

## Date

2026-08-08

## Superseded By

- [0631 Remove Apple Intelligence Task Relationship Suggestions](../0631-remove-apple-intelligence-task-relationship-suggestions.md)

## Refines

- [0486 Suggest Confirmed Task Relationships On Device](../0486-suggest-confirmed-task-relationships-on-device.md)

## Context

Task Details originally exposed the on-demand Apple Intelligence relationship
suggestion workflow on both iOS and macOS. On iOS, it adds nonessential controls
and status content to a compact detail screen. The Mac app is the intended place
for relationship discovery and its dedicated review workflow.

## Decision

iOS Task Details keep the manual linked-task controls, including creating or
linking a task and viewing existing links. They do not show Apple Intelligence
suggestion controls, suggestion cards, status messages, or the explanatory
placeholder, and cannot start a relationship-suggestion request from the UI.

macOS Task Details retain the on-demand `Suggest` action and its explicit
confirmation workflow. The Mac `Review Task Relationships` window remains
unchanged. Shared relationship-suggestion state and effects remain available to
support those Mac surfaces.

## Consequences

- iOS Task Details stay focused on explicit, manual relationship management.
- Any residual suggestion state synced or retained during a platform transition
  is not presented on iOS.
- macOS remains the sole UI entry point for Apple Intelligence relationship
  suggestions and catalog review.
