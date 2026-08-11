# 0148 — Coalesce Backlog refreshes

Date: 2026-08-12

## Symptom

The Mac Backlog refresh control repeatedly flashed while the window was open,
sometimes multiple times per second.

## Root Cause

Backlog observed every raw `ModelContext.didSave` notification. SwiftData and
CloudKit can emit many such saves for one logical change, and each one rebuilt
the complete Backlog presentation and toggled the toolbar control's loading
state.

## Fix

Backlog now uses Routina's semantic routine-update notification, which already
receives coalesced CloudKit updates, then applies its own cancel-in-flight
450-millisecond debounce before refreshing its snapshot.

## Prevention Rule

Do not connect an unbounded task presentation directly to raw SwiftData save
notifications. Use the app-owned semantic update fan-in and coalesce bursts
before fetching or rebuilding a complete presentation snapshot.

## Regression Safeguard

`PerformanceRegressionTests.testBacklogUsesCoalescedSemanticRefreshes` rejects
raw save observation and requires the semantic, cancellable debounce path. The
expected user-visible behavior is recorded in `docs/scenarios/README.md`.
