# 0207 Show Timeline Oldest to Newest

Status: Accepted

Date: 2026-06-11

Refines: [0206 Capture Status From Mac Sidebar](0206-capture-status-from-mac-sidebar.md)

## Context

Status capture makes Timeline feel closer to a chat transcript. Users expect the newest chat-like entry to sit at the bottom, with older history above it.

## Decision

Timeline groups and entries render in chronological order: oldest days first, and oldest entries first within each day. Timeline list surfaces use a bottom default scroll anchor so the latest visible entry is near the bottom when the list opens.

Split-view timeline selection falls back to the latest visible entry instead of the first visible entry.

## Consequences

Timeline reading order now matches chat-style status capture and still preserves normal accessibility order.

Users scroll upward to review older timeline history.
