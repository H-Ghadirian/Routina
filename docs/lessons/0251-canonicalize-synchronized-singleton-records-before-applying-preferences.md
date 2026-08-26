# 0251 — Canonicalize synchronized singleton records before applying preferences

Date: 2026-08-26

## Symptom

Backlog super sections and subsections created on Mac did not appear in the iOS
Backlog even though the iOS workspace rendered the shared Backlog hierarchy.

## Root Cause

Mac and iOS could each insert a `RoutinaUserPreferences` row for the same logical
singleton before CloudKit imported the other device's row. SwiftData treated
those inserts as separate persistent records even though their app-level `id`
values matched. The preference bridge fetched an arbitrary first match, so iOS
could repeatedly apply its older empty custom-section catalog.

## Fix

The preference bridge now ranks matching singleton rows by `updatedAt`, applies
the newest record, deletes stale duplicates, and saves that consolidation. The
same canonicalization runs before local preference mirroring so later writes
continue from the surviving record.

## Prevention Rule

An app-level singleton identifier does not guarantee one SwiftData or CloudKit
record. Every synchronized singleton read and write boundary must resolve
duplicate persistent rows deterministically before using or updating the value.

## Regression Safeguard

`RoutinaUserPreferencesStoreTests.preferenceBridgeAppliesNewestDuplicateAndRemovesStaleRecord`
creates an older empty preference row and a newer row containing the Mac Backlog
catalog, then verifies that applying preferences chooses the newer catalog and
leaves only one record. The cross-device expectation is also recorded in
`docs/scenarios/README.md`.
