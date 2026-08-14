# 0567 — Defer iOS Home Refreshes Until Scrolling Is Quiet

**Status:** Accepted
**Date:** 2026-08-14

## Refines

- [0418 — Keep Whole-History Work Out of Scrolling Render Paths](0418-keep-whole-history-work-out-of-scrolling-render-paths.md)
- [0419 — Use Lightweight Surfaces Inside Unbounded Scroll Rows](0419-use-lightweight-surfaces-inside-unbounded-scroll-rows.md)
- [0543 — Defer iOS Sync Refresh Work Until Its Tab Is Active](0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)

## Context

A physical-device Release trace of continuous iOS Home scrolling recorded
10.624 seconds of Routina main-thread CPU over a 34.5-second trace. Roughly
every two to three seconds, Home spent about 200–260 milliseconds loading the
complete task snapshot, deriving timeline fallbacks, applying loaded models,
and rebuilding displays. The same bursts continued after the scrolling
gesture stopped.

CloudKit import and remote-change events are intentionally coalesced into
semantic `.routineDidUpdate` notifications, but active iOS Home responded to
every delivered notification by starting a full main-actor reload. A second
observer independently fetched all attachment rows. macOS Home already
deferred comparable work behind a scroll-quiet gate; iOS Home had no equivalent
boundary.

## Decision

Active iOS Home and the Home-backed Search surface coalesce routine-update
notifications for 450 milliseconds. List offset changes record scroll
activity. If a refresh becomes due while a Home list has moved within the last
1.2 seconds, Home retains one pending invalidation and retries after the quiet
window instead of fetching or rebuilding during the gesture.

When the list is quiet, Home performs one refresh for all coalesced
notifications. The refresh owns both the task snapshot reload and attachment
ID fetch so no independent notification observer can query SwiftData during
scrolling. Local reducer mutations remain immediate, and inactive tabs retain
their existing single deferred-refresh behavior from Decision 0543.

## Consequences

- CloudKit and persistence pulses no longer insert complete Home reloads into
  active scrolling transactions.
- Remote changes can appear shortly after scrolling stops rather than during
  the gesture; they are delayed, never discarded.
- Repeated notifications received during one gesture collapse into one reload.
- The main-actor Home load remains measurable work after the quiet window;
  moving more of that pipeline off the main actor is a separate optimization.
