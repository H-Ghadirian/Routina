# 0419: Refresh Stats on Meaningful Surface Events

Date: 2026-07-23

## Status

Accepted

## Context

Stats fetches every major model collection and builds a large immutable derived
presentation. Listening directly to every SwiftData save or app-wide
`routineDidUpdate` notification made that work repeat while Stats was idle.
Cloud and persistence coordination can emit those broad notifications even when
the displayed statistics have not materially changed.

[0137](0137-show-active-focus-in-stats-today.md) also requires an active,
unpaused focus session to remain current while Stats is open.

## Decision

Stats refreshes its full data snapshot:

- on its first appearance;
- when macOS crosses from another mode into Stats (duplicate selection actions
  while Stats remains selected do not refresh); and
- every 30 seconds while an unpaused task or sprint focus session is active.

Stats feature-setting changes continue to request their own refresh. The visible
Stats view does not subscribe directly to raw model-context saves or the broad
app-wide routine update channel. The active-focus timer is reducer-owned and
cancel-in-flight so SwiftUI view reconstruction cannot accumulate timer tasks.

## Consequences

- Idle Stats no longer pays repeated whole-history fetch and derivation costs
  because of unrelated persistence or sync traffic.
- Re-entering Stats provides a fresh authoritative snapshot.
- Active focus totals remain live at a bounded cadence without keeping idle
  dashboards on a timer.
- A background cloud change may not appear in an already-open idle Stats window
  until Stats is re-entered.

## Related Decisions

- [0137: Show Active Focus in Stats Today](0137-show-active-focus-in-stats-today.md)
- [0417: Route Feature Data Loading Through Reducers](0417-route-feature-data-loading-through-reducers.md)
- [0418: Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
