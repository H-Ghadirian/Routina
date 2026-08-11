# 0543: Defer iOS Sync Refresh Work Until Its Tab Is Active

## Status

Accepted

## Date

2026-08-11

## Refines

- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0541: Keep iOS Search Input Ahead of Home Presentations](0541-keep-ios-search-input-ahead-of-home-presentations.md)

## Context

The physical-device Release profile of Home and Search showed that a retained
`TabView` destination could still observe update notifications and rebuild its
complete presentation while another tab owned the screen. Home performed its
full-history repair pass during those ordinary refreshes, and Timeline fetched
and regrouped its complete SwiftData snapshot while Home or Search was active.
Those main-actor operations delayed keyboard and transition work.

The existing Home-maintenance lesson already establishes that repair work is
only valid when creating the initial snapshot. The iOS implementation had
regressed that boundary.

## Decision

On iOS, Home, Search, and Timeline receive an explicit active-tab state from
the app shell. An inactive destination performs no attachment fetch, list
presentation rebuild, Timeline snapshot fetch, or synchronization-triggered
derived-state rebuild. When a destination becomes active, it performs the
single refresh needed to establish an initial or deferred snapshot.

Home runs deduplication, history backfill, and orphan cleanup only while
creating its first task snapshot. Ordinary app updates, reappearances, and
post-mutation refreshes use the lightweight load path. Search retains the raw
input/applied-query boundary from [0541](0541-keep-ios-search-input-ahead-of-home-presentations.md).

## Consequences

- Search keyboard and transition work no longer competes with retained Home or
  Timeline tabs for main-thread time.
- A remote change received while Timeline is inactive becomes visible when the
  person returns to Timeline, preserving explicit sync invalidation without
  background list reconstruction.
- Whole-history Home repairs cannot recur for every routine update.
- Each active tab remains responsible for presenting a current snapshot when it
  becomes visible.
