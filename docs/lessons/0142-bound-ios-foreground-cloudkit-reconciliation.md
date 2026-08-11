# 0142 — Bound iOS foreground CloudKit reconciliation

Date: 2026-08-11

## Symptom

Home, Search, and Timeline could stop responding after launch or when the app
returned to the foreground. Search keystrokes then accumulated and appeared at
once after the UI became responsive.

## Root Cause

The foreground active-Focus reconciler fetched the entire private CloudKit zone
from a nil change token and merged it on the main actor. Every tombstone in
that replay separately scanned retained tasks, logs, Focus rows, attachments,
and planner blocks.

## Fix

Foreground reconciliation now queries only active Focus and sprint-Focus
records, plus direct record-ID reads for locally active timers so remote stops
remain visible. Full-zone manual reconciliation batches every deletion ID and
scans each related model collection once; log deduplication also retains direct
row references instead of repeatedly searching the full log array.

## Prevention Rule

Foreground and interactive UI paths must never replay unbounded CloudKit
history. A sync cleanup that receives a set of records must process that set in
one pass, not invoke complete-history cleanup once per record.

## Regression Safeguard

`CloudKitDirectPullDeletionTests.cloudKitMerge_batchesMultipleDeletedTasksWithoutRemovingKeptHistory`
checks batched cleanup behavior. `IOSScrollingPerformanceRegressionTests`
checks the bounded foreground query and deletion architecture. Decision
[0545](../decisions/0545-bound-ios-foreground-focus-reconciliation.md) and the
cross-device Focus scenario record the contract.
