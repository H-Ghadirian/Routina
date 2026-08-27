# 0683: Omit Idle Copy from Mac Shared Filter Groups

## Status

Accepted

## Date

2026-08-27

## Revises

- [0679: Edit Mac Shared Tag and Flag Rules in Combined Popovers](0679-edit-mac-shared-tag-and-flag-rules-in-combined-popovers.md)

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)

## Context

The titled Tags and Flags panels already identify the filter family, while their
single edit actions make the idle state apparent. Repeating `No tag filters` or
`No flag filters` between the title and action adds height without helping the
person choose or understand an available action.

## Decision

- An idle Mac Shared Tags or Flags panel places its edit action directly below
  the title and omits `No tag filters` and `No flag filters` copy.
- When a rule is active, its Include and Exclude summaries remain visible as
  directly removable chips with meaningful All/Any modes.
- Popover behavior, matching semantics, persistence, colors, and ownership do
  not change.

## Consequences

- Idle panels are shorter and visually quieter.
- Active filter state remains explicit without adding redundant empty-state
  messaging.
