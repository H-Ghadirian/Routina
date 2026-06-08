# 0188: Prefer Self-Explanatory UI Over Instructional Copy

## Status

Accepted

## Date

2026-06-08

## Context

Routina has accumulated form sections, filters, and settings that sometimes explain themselves with visible captions, repeated headings, and instructional text. That can make useful controls feel heavier than the action they represent, especially in dense task editing surfaces where the user already understands the domain.

## Decision

Routina UI should be self-explanatory first. Prefer hierarchy, placement, familiar icons, native controls, chip state, enabled/disabled affordances, color, progressive disclosure, and clear placeholders over visible instructional copy.

Visible explanatory text is reserved for genuinely ambiguous, destructive, high-stakes, or domain-specific behavior that cannot be made clear through the interaction itself. Desktop help text, accessibility labels, and native assistive labels should remain even when visible copy is reduced.

## Consequences

- Future UI work should ask whether a heading, caption, or description can be replaced by better structure or state.
- Dense forms should avoid redundant micro-headings when section titles, placeholders, chips, and icons already communicate the action.
- Accessibility and discoverability stay supported through labels and help text even when the visible interface is quieter.
