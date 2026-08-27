# 0678: Group Mac Shared Tag and Flag Actions

## Status

Accepted

## Date

2026-08-27

## Refines

- [0188: Prefer Self-Explanatory UI Over Instructional Copy](0188-prefer-self-explanatory-ui-over-instructional-copy.md)
- [0316: Present Mac Home Filters as a Companion Pane](0316-present-mac-home-filters-as-companion-pane.md)
- [0671: Present Mac Shared Tags as Direct Actions](0671-present-mac-shared-tags-as-direct-actions.md)
- [0677: Centralize Mac Flag Filters Under Shared](0677-centralize-mac-flag-filters-under-shared.md)

## Context

Shared presented Include and Exclude as four consecutive tinted action surfaces.
Although the labels named each operation, the layout did not visually establish
which pair belonged to Tags and which pair belonged to Flags. The independent
backgrounds also made each action read like a separate top-level filter section.

## Decision

- Mac Shared places `Include flags` and `Exclude flags` together in an
  always-expanded `Flags` group with an orange-tinted panel background and Flag
  icon.
- It places `Include tags` and `Exclude tags` together in an always-expanded
  `Tags` group with a teal-tinted panel background and Tag icon.
- These groups are visual containers, not disclosures. Both actions remain
  immediately available without an additional click.
- The actions retain their semantic tints, full-surface hit areas, searchable
  pickers, selected chips, and conditional All/Any controls.
- Filter semantics, persistence, cross-surface ownership, catalog caching, and
  the separate Stats presentations do not change.

## Consequences

- A person can distinguish the Flags and Tags filter families before reading
  each action label.
- Include and Exclude remain direct while their shared ownership is explicit.
- The colored group panels align these filters with the titled visual hierarchy
  used by the adjacent Task Ladder values section without adding disclosure
  state.
