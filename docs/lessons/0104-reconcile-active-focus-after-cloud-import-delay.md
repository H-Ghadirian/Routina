# 0104 — Reconcile active Focus after CloudKit import delay

Date: 2026-08-08

## Symptom

After a Focus session was stopped on macOS, iOS could still show that session as ongoing even after the iOS app was relaunched.

## Root Cause

The app relied on SwiftData's asynchronous CloudKit mirroring for Focus lifecycle updates. iOS refreshed its surfaces when sync notifications arrived, but did not reconcile a locally active timer with the CloudKit record on launch, and the direct-pull fallback did not understand Focus-session records.

## Fix

The direct CloudKit pull now merges task and Sprint Focus lifecycle records, preserving terminal states against delayed active records. When iOS opens with an active Focus session, it performs one bounded reconciliation and one short retry to absorb a just-exported stop event.

## Prevention Rule

For cross-device state that changes whether a timer is visibly running, refresh notifications alone are insufficient: the active-state owner must reconcile the terminal record, and stale active data must never reopen a finished session.

## Regression Safeguard

`Tests/Shared/CloudKitDirectPullFocusSessionTests.swift` verifies that a remote terminal update closes a local active session and that a delayed active record cannot reopen it. The cross-device contract is recorded in `docs/scenarios/README.md`.
