# 0527: Keep Mac Task Detail Overflow Compact and Stateful

Status: Accepted

Date: 2026-08-09

Refines: [0521 Group Secondary Mac Task Detail Actions](0521-group-secondary-mac-task-detail-actions.md)

## Context

The secondary-action menu correctly grouped lifecycle and destructive controls,
but a standard rectangular toolbar trigger did not make its open state clear or
match the compact vertical-overflow affordance used by the target interaction.
A large custom action panel would add visual weight that the short action list
does not need.

## Decision

Mac Task Details retains the compact native overflow menu. Its trigger uses the
vertical `⋮` symbol, has no idle container, and receives a circular accent
highlight only while the native menu is open. The active circle clears as soon
as the menu closes.

The menu continues to use ordinary compact macOS rows rather than a custom
large panel. Delete remains the final separated destructive row with its
existing confirmation dialog.

## Consequences

- The overflow affordance has an obvious active state without adding a persistent
  button container to the header.
- The header retains a compact macOS interaction for its short action list.
- Delete stays visually and behaviorally distinct from reversible lifecycle
  actions.
