# 0054: Open iOS Home Top Actions Vertically

## Status

Accepted

## Date

2026-05-25

## Context

Compact iOS Home exposed the top-right Home actions by expanding additional toolbar buttons horizontally inside the navigation bar. That kept actions close to the ellipsis button, but it quickly consumed the title area and left little room for additional actions.

The bottom Home controls already use compact trailing icon buttons, so the top Home action expansion should stay compact while avoiding horizontal pressure on the navigation bar.

## Decision

The iOS Home top-right actions expand into a vertical icon rail anchored under the navigation button instead of adding more primary toolbar items.

The rail keeps Quick Add, Filters, and Add Task as icon actions with accessibility labels. The toolbar keeps a single ellipsis/collapse control, and selecting any rail action collapses the expanded state before opening the target flow.

## Consequences

- Home can add more top actions without squeezing the navigation title.
- The action reveal remains a lightweight two-tap interaction rather than a full sheet or menu.
- The vertical rail should remain icon-first and accessible so it fits the compact Home surface.
