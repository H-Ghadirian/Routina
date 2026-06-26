# 0207 Show Timeline Oldest to Newest

Status: Superseded

Superseded by: [0242 Show Timeline Sections Top-Down](0242-show-timeline-sections-top-down.md), then [0280 Show Timeline Newest First](../0280-show-timeline-newest-first.md)

Date: 2026-06-11

Refines: [0206 Capture Status From Mac Sidebar](0206-capture-status-from-mac-sidebar.md)

## Context

Status capture makes Timeline feel closer to a chat transcript. Users expect the newest chat-like entry to sit at the bottom, with older history above it.

## Decision

Timeline groups and entries are derived in chronological order: oldest days first, and oldest entries first within each day.

Timeline list surfaces present that chronology with an inverted chat-list layout: the newest section and entry render first in the underlying list, the list is vertically inverted, and each row/header is flipped back upright. This makes the latest visible entry appear at the bottom on first paint without a post-load scroll or jump.

Split-view timeline selection falls back to the latest visible entry instead of the first visible entry.

## Consequences

Timeline visual order now matches chat-style status capture.

Users scroll upward to review older timeline history.
