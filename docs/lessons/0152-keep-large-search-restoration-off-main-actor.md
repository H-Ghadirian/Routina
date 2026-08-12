# 0152 — Keep large Search restoration off the main actor

Date: 2026-08-12

## Symptom

After a large no-match Search became fast, clearing the query could still
produce a visible hiccup while 12,000 normal task rows returned. Repeated
open, type, clear, and keyboard-close cycles made the delay easier to expose.

## Root Cause

The filtered presentation itself built away from the main actor, but the iOS
list then rebuilt a full task-ID-to-row-number dictionary in its main-actor
SwiftUI task. The result/empty-state branch also removed and reinserted the
entire native `List`, while an implicit presentation-revision animation could
apply to that large hierarchy. Visible row metadata also recreated the complete
Home filtering/configuration object during row rendering just to obtain scalar
elapsed-time and urgency values.

## Fix

Row-number lookup now builds from the immutable presentation in cancellable
user-initiated detached work. The task list stays mounted across result and
empty states, presentation-wide implicit animation is removed, and only the
small empty-state overlay receives an opacity transition.
Row metadata now derives those scalar values from the immutable display and a
reference date, without rebuilding filtering state.

## Prevention Rule

Moving the primary filter off-main is not enough: audit every derived lookup,
post-processing task, and structural SwiftUI transition that runs when a large
snapshot is published or restored. Keep stable native containers mounted and
limit animation transactions to small overlays.

## Regression Safeguard

`IOSScrollingPerformanceRegressionTests.homeUsesCachedPresentationAndStableTaskIDs`
protects detached row-number construction, cancellation, stable list
structure, the absence of presentation-wide animation, and lightweight row
metadata construction.
`RoutinaUIPerformanceTests.testLargeSeededRapidNoMatchSearchPerformance`
repeats four keyboard-open, long-query, no-match, clear, full-list-restore, and
native-close cycles against 12,000 seeded tasks. Decision
[0557](../decisions/0557-build-ios-search-presentations-off-main-actor.md)
records the durable boundary.
