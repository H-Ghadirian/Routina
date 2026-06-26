# 0280 Show Timeline Newest First

Status: Accepted

Date: 2026-06-26

Supersedes: [0242 Show Timeline Sections Top-Down](superseded/0242-show-timeline-sections-top-down.md)

## Context

Timeline briefly returned to a top-down chronological list where the oldest day and oldest entry appeared first. That kept date headers above their rows, but it made the newest activity land at the bottom of the list.

The Timeline is a history review surface where the most recent evidence is usually the most useful entry. A normal, non-inverted list can still put date headers above their rows while showing the latest activity first.

## Decision

Timeline surfaces render as normal, non-inverted lists ordered newest first: newest day first, newest entry first within each day, and each date header above its related rows.

Split-view timeline selection falls back to the first visible entry because that entry is now the latest visible activity.

Initial timeline positioning anchors to the top of the list rather than the bottom.

## Consequences

The latest timeline entry appears at the top without using inverted chat-list transforms.

Users scroll downward to review older timeline history.

Date grouping stays visually direct because headers still appear above the rows they describe.
