# 0121: Show Focus 2048 Earned Tiles

## Status

Accepted

## Date

2026-05-31

## Context

The Focus 2048 tile math intentionally merges every full two-hour focus chunk into the smallest set of power-of-two hour tiles. Rendering that merged result inside a fixed 4x4 board leaves most cells empty for ordinary focus totals, making the section feel sparse and unclear.

## Decision

The Focus 2048 section renders only earned merged tiles in a compact adaptive layout. It also shows one muted preview tile for the next two-hour chunk, with progress handled by the existing progress indicator.

The section remains read-only and deterministic. The tile-generation math from [0120](0120-show-focus-2048-board.md) remains unchanged.

## Consequences

- The visual emphasizes earned focus tiles instead of empty board capacity.
- Users can still understand the next milestone through the preview tile and progress bar.
- No persistence or stats calculation changes are required.
