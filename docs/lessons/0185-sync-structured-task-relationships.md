# 0185 — Sync structured task relationships

Date: 2026-08-16

## Symptom

A task created as Blocked on Mac appeared as To Do on iOS, and iOS Task
Details omitted the Linked Tasks section entirely.

## Root Cause

SwiftData persisted `relationshipsStorage`, but the direct CloudKit task parser
and payload applier omitted that structured field. A direct refresh could merge
the task's ordinary fields without restoring its relationships on another
device.

## Fix

Direct CloudKit pull now decodes and applies serialized task relationships for
both new and existing tasks. An explicit empty payload clears deleted links,
while a legacy or partial record with no relationship field preserves local
relationship data.

## Prevention Rule

When a synchronized model adds structured storage, audit every custom sync
parser and payload applier. Preserve the distinction between an absent field and
a present field containing an empty collection.

## Regression Safeguard

`CloudKitDirectPullTaskRelationshipTests` verifies that a relationship round
trip restores the derived Blocked state, missing storage is non-destructive, and
explicit empty storage removes relationships.
