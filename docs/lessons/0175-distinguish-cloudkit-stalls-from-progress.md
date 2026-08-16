# 0175 — Distinguish CloudKit stalls from progress

Date: 2026-08-16

## Symptom

The first fix for an endless manual iCloud refresh stopped the operation after
60 seconds even when CloudKit was still delivering a large production zone.
The person saw a timeout despite a working connection, and retrying replayed
the same full zone.

## Root Cause

The app treated total elapsed time as proof that CloudKit had stalled and did
not persist the server-change token returned by a successfully merged pull.
The deadline therefore could not distinguish silence from useful progress, and
every manual refresh started from the beginning.

## Fix

Manual refresh now resets its one-minute inactivity watchdog whenever CloudKit
delivers record or zone activity, retains a separate three-minute hard limit,
and reports received-item progress. Routina saves a per-container change token
only after the complete response merges and saves locally. Record failures,
merge failures, cancellation, timeout, reset, import, and expired tokens cannot
advance or retain an unsafe baseline.

## Prevention Rule

For progress-producing platform APIs, define inactivity and total-operation
limits separately. Persist a continuation cursor only at the same atomic
boundary where all data represented by that cursor has been applied
successfully; never advance it from a partial callback or failed merge.

## Regression Safeguard

`CloudKitSyncDiagnosticsTests.manualRefreshResetsInactivityOnProgressAndSavesTokenOnlyAfterMerge`
protects the activity-reset and token-ordering invariants.
`CloudKitSyncDiagnosticsTests.manualRefreshFeedbackDistinguishesNoResponseFromSlowProgress`
protects the recovery distinction, and the Manual iCloud Refresh scenario
records the Settings/Home product contract. This lesson follows up
[0173](0173-bound-user-initiated-cloudkit-refreshes.md), whose absolute
deadline fixed the endless spinner but did not yet distinguish active work.
