# 0501: Collapse User-Completed Home Task-List Rows Within Their Sections

Status: Accepted

Date: 2026-08-07

Refines: [0252 Stabilize Home Task List Presentation Identity](0252-stabilize-home-task-list-presentation-identity.md), [0418 Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md), [0495 Let Task-List Filters Hide Assumed-Done Rows](0495-let-task-list-filters-hide-assumed-done-rows.md)

## Context

Completed work is valuable as a record, but it can make each Home task-list
section difficult to scan for the next action. Hiding all completed rows would
remove useful context and make completion reversal harder to discover.

Assumed-done rows are different: they are provisional state with correction
actions, and Decision 0495 deliberately keeps them visible by default.

## Decision

Each Home task-list section places tasks that the person actually completed in
a trailing `Completed` subgroup. The subgroup is initially collapsed and shows
its count; expanding it is retained per stable section identity. A task search
temporarily reveals matching completed rows.

An actually completed row is a completed one-off task or a row that is done
today without being assumed done. Assumed-done rows remain in their ordinary
visible group and continue to follow the separate task-list filter from
Decision 0495.

The shared immutable task-list presentation snapshot owns this partitioning.
Platform views only render the prepared groups and their disclosure state.

## Consequences

- Active work remains prominent while completed work stays one expansion away.
- iOS and macOS use the same completion classification and stable subgroup
  identity.
- Searches do not hide matching completed rows behind a disclosure.
- The task-list scroll path does not filter or regroup the full model
  collection during rendering.
