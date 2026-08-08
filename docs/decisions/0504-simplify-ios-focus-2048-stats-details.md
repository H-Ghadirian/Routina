# 0504: Simplify iOS Focus 2048 Stats Details

## Status

Accepted

## Date

2026-08-08

## Refines

- [0120](0120-show-focus-2048-board.md)
- [0121](0121-show-focus-2048-earned-tiles.md)

## Context

The Focus 2048 section already communicates accumulated work through earned
tiles, a next-tile preview, and progress to the next two-hour tile. On iOS,
the largest-tile callout, earned-tile count, and three supplemental insight
pills compete with that visual and make the card heavier than necessary.

## Decision

iOS Focus 2048 keeps the title, earned tiles, preview tile, and next-tile
progress bar. It omits the Largest tile callout, earned-tile count, and
supplemental insight pills.

macOS retains the supplementary details. Tile math, filtering, progress, and
persistence remain unchanged on both platforms.

## Consequences

- iOS presents one focused visual hierarchy for accumulated focus.
- The earned and preview tiles remain the source of milestone information.
- The shared section supports deliberate platform-specific detail levels
  without duplicating its tile or progress implementation.
