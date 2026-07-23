# 0004 — Do not reload Stats on view reappearance

## Symptom

The macOS Stats surface repeatedly fetched every model collection and rebuilt all
derived statistics while it was already visible. CPU stayed elevated, scrolling
stuttered, and transient memory climbed above 400 MB.

## Root Cause

`StatsDataObserver` sends `StatsFeature.Action.onAppear` from a SwiftUI task.
SwiftUI may recreate that observer as its surrounding hierarchy changes, so the
action is not a once-per-application lifecycle signal. The reducer treated every
appearance as an unconditional full data refresh.

## Fix

`StatsFeature.State` now records whether a complete data snapshot has loaded.
Repeated appearance actions retain settings updates but skip the full fetch and
derived-state rebuild. Persistence and domain notifications use a cancellable
one-second quiet window, collapsing a burst into one authoritative refresh.
Stats refreshes when the user enters the surface and at a bounded cadence only
while an unpaused focus session is active. It does not listen to raw
`ModelContext.didSave` or broad `.routineDidUpdate` traffic, so unrelated
internal and sync activity cannot invalidate the whole dashboard.
Mac mode selection is edge-triggered in app state so duplicate “Stats selected”
actions do not count as repeated entries.
The active-focus ticker is reducer-owned with a cancel-in-flight identity so
recreated SwiftUI observers cannot accumulate overlapping timers.

## Prevention Rule

Never use SwiftUI appearance alone as proof that an expensive feature snapshot is
stale. Keep an explicit loaded/stale marker in feature state, and reserve
appearance-triggered full loads for the initial empty state. Coalesce persistence
and domain notification bursts before rebuilding an expensive snapshot. Prefer
explicit surface-entry and genuinely live-domain events over broad app-wide
notifications.

## Regression Safeguard

The macOS performance regression suite checks that Stats sets and consults its
loaded-snapshot marker before launching the appearance refresh, and that
notification refreshes use a cancel-in-flight debounce. It also rejects a raw
`ModelContext.didSave` or broad `.routineDidUpdate` subscription in the Stats
view, and preserves the bounded active-focus refresh.
