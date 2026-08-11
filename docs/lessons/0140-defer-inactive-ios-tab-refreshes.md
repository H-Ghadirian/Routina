# 0140 — Defer inactive iOS tab refreshes

Date: 2026-08-11

## Symptom

On a physical production iPhone, Home and Search stuttered and Search input
could queue then flush. The Release profile showed Home and Timeline work on
the main thread while Search was the visible destination.

## Root Cause

SwiftUI retained tab destinations continued receiving Routina's semantic update
notification. The inactive Home and Timeline surfaces fetched data and rebuilt
unbounded presentations even though their tab was not visible. iOS Home also
ran whole-history maintenance during every normal reload instead of only while
establishing its initial snapshot.

## Fix

The app shell now supplies active-tab state to Home, Search, and Timeline.
Inactive destinations defer refresh work until selected. iOS Home again passes
the initial-snapshot state to its loader, so routine refreshes skip maintenance.

## Prevention Rule

An inactive retained iOS tab must not fetch SwiftData, rebuild an unbounded
presentation, or react to a semantic synchronization update. Whole-history
repair belongs exclusively to an explicit initial, migration, or maintenance
boundary.

## Regression Safeguard

`Tests/Shared/IOSScrollingPerformanceRegressionTests.swift` checks the
active-tab gates, deferred Home refresh boundary, Timeline task gate, and
initial-only maintenance argument. Decision
[0543](../decisions/0543-defer-ios-sync-refresh-work-until-its-tab-is-active.md)
and the iOS synchronization scenario record the intended behavior.
