# 0459: Route a Single iOS New Action Directly

## Status

Superseded by [0695](../0695-promote-stats-and-settings-in-ios-navigation.md)

## Date

2026-07-29

## Refines

- [0173: Use iOS New Tab Sheet](0173-use-ios-new-tab-sheet.md)
- [0458: Align iOS New Actions With Beta Gates](0458-align-ios-new-actions-with-beta-gates.md)

## Context

Feature availability can reduce the iOS bottom-bar New actions to Task alone.
Presenting a non-full-screen chooser containing only that one row adds a tap
without offering a choice.

The chooser remains useful whenever two or more creation or session actions are
available.

## Decision

Tapping the iOS bottom-bar New action derives the currently available,
feature-gated actions before choosing its presentation:

- one available action routes directly through the existing guarded action
  handler;
- two or more available actions open the New chooser;
- no available actions perform no navigation, although Task is currently always
  available.

The destination handler retains its independent feature guards so a direct or
queued action cannot bypass current availability.

## Consequences

- Default configurations with Task as the only action open task creation in one
  tap.
- Enabling any optional New action restores the chooser.
- The chooser never appears merely to repeat a single destination.
