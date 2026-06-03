# 0017: Show Mac Map Check-In Inline

## Status

Superseded by [0018](0018-show-mac-map-check-in-in-detail-column.md)

## Date

2026-05-10

## Context

The map check-in flow was introduced as a shared sheet so it could work on iPhone and Mac with one implementation. On Mac, a modal sheet interrupts the main-window workflow and hides surrounding task context.

## Decision

Mac Home opens map check-in as an inline panel in the main window. The shared dock exposes a map-request callback so platform owners can choose the presentation. iPhone keeps the sheet presentation, while Mac renders the same map content with inline chrome and a close button.

## Consequences

- Mac users can check in and review the place/day timeline without leaving the main Home window context.
- The shared map behavior remains centralized, with only the presentation shell differing by platform.
- The inline panel is transient UI state owned by the Mac Home view, not a separate window or modal flow.
