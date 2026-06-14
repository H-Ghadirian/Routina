# 0242 Show Timeline Sections Top-Down

Status: Accepted

Date: 2026-06-25

Supersedes: [0207 Show Timeline Oldest to Newest](superseded/0207-show-timeline-oldest-to-newest.md)

## Context

The inverted chat-style timeline made the newest visible activity sit near the bottom on first paint, but it also inverted section layout side effects. Date headers appeared visually below their related rows, and short timelines left unused space above the list content.

Timeline rows read more clearly when a date title introduces the rows that belong to that date.

## Decision

Timeline surfaces render sections top-down in chronological order: oldest day first, oldest entry first within each day, and each date header above its related rows.

The list is no longer vertically inverted. When only a few rows are visible, unused space remains below the row list.

Split-view timeline selection still falls back to the latest visible entry for detail presentation.

## Consequences

Date grouping is visually direct and native `List` layout behavior is preserved.

The latest timeline entry remains the last item in the chronological content, but timeline views no longer bottom-align short content just to mimic chat presentation.
