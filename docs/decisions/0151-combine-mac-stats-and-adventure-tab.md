# 0151: Combine Mac Stats and Adventure in One Tab

## Status

Accepted

## Date

2026-06-03

## Context

Adventure is a game-like presentation of the same activity history that powers Stats. The first Mac MVP exposed Adventure as its own sidebar destination, but that made the Home sidebar busier and separated the motivational map from the factual progress surface it is derived from.

The user wants Stats and Adventure to live in one tab and switch with a segmented control, matching the existing Mac Home detail-mode picker pattern.

## Decision

Routina Mac exposes Stats and Adventure through one sidebar tab. The detail toolbar shows a `Stats / Adventure` segmented control when that tab is active. Selecting Stats shows the existing Stats dashboard; selecting Adventure shows the Adventure map and its matching Adventure sidebar summary.

The old Adventure sidebar mode remains as a compatibility route for commands and persisted temporary state, but it resolves to the Stats sidebar tab. The Adventure command opens the combined tab with the Adventure segment selected.

## Consequences

- The Mac sidebar stays simpler while Adventure remains reachable from the keyboard/menu command and the top segment.
- Back/Forward history records whether the combined progress tab was showing Stats or Adventure.
- Future game-layer additions should prefer this combined progress surface unless they become a distinct workflow with their own sidebar-worthy navigation model.
