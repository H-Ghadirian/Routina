# 0120: Show Focus 2048 Board

## Status

Accepted

## Date

2026-05-31

## Context

Focus charts show duration trends, but they do not provide a playful summary of how focus compounds over the selected Stats range.

## Decision

Stats includes a read-only Focus 2048 section on iOS and macOS. Every full two hours of filtered focus time creates a base `2` tile, and those base tiles are merged into the largest possible power-of-two hour tiles, matching the 2048 visual metaphor.

The board is generated from existing focus-session totals for the selected Stats range and filters. Partial progress toward the next two-hour tile is shown separately.

## Consequences

- Users get a compact, motivating visual for accumulated focus without introducing a playable game or new persistence.
- The tile values are focused hours, so the section labels tiles as hours and shows total focus alongside the board.
- Focus 2048 stays consistent with existing focus stats because it derives from the same filtered focus total.
