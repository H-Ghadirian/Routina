# 0115: Support Compact Stats Summary Cards

## Status

Accepted

## Date

2026-05-31

## Context

Stats summary cards expose many factual totals, but the default card layout is spacious and can require a lot of scrolling when the user wants to scan the full set.

## Decision

Stats supports a summary display mode control on iOS and macOS with Cards and Compact options. Cards keeps the existing spacious card grid. Compact uses shorter summary rows with the same values, captions, colors, and accessories.

The selected summary display mode is stored separately for iOS and macOS so each platform can keep its preferred density. The mode changes presentation only; dashboard ordering, hidden items, filters, and metrics remain unchanged.

## Consequences

- Users can scan more summary metrics without hiding cards.
- Existing large summary cards remain the default.
- Compact mode can evolve as a presentation style without changing the underlying stats data model.
