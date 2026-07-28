# 0056 — Preserve local drafts across catalog writes

Date: 2026-07-28

## Symptom

In Mac Settings -> Sections, changing a section color or another catalog value
could erase an unfinished section-name or automatic-tag edit.

## Root Cause

Every AppStorage persistence update rebuilt all editor drafts directly from the
saved section catalog. The synchronization path did not distinguish an
untouched field from a locally edited field that had not been saved yet.

## Fix

The section editor now tracks the last synchronized title and tag value beside
each local draft. Incoming persistence updates replace only drafts that still
match their previous synchronized value; locally changed drafts survive.
Deleted-section drafts are removed normally.

## Prevention Rule

When a settings screen contains several independently persisted controls, do
not rebuild every text draft after any shared-storage write. Track the last
persisted value per field and merge incoming data only into untouched drafts.

## Regression Safeguard

`Tests/Shared/HomeCustomTaskSectionStorageTests.swift` verifies that a
color-only catalog update preserves unfinished title and tag drafts while
untouched drafts still adopt external title and tag changes.
