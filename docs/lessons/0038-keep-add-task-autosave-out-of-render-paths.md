# 0038 — Keep Add Task autosave out of render paths

Date: 2026-07-26

## Symptom

Changing recurrence choices in Add Task became visibly slow, and the expanded form was difficult to scroll smoothly on both iOS and macOS.

## Root Cause

The Add Task views constructed and compared a complete Codable draft snapshot directly from `store.state` inside SwiftUI `body`, then synchronously encoded and wrote the snapshot for every mutation. Shared segmented controls also wrapped their owner-state mutation in `withAnimation`, which animated the whole form as recurrence fields appeared or disappeared. Fixed schedule details additionally rebuilt the complete time-zone catalog in the scrolling form.

## Fix

Add Task draft autosave is now scheduled by the feature after state mutations. Writes are coalesced for 180 milliseconds, encoded on a utility queue, and canceled before Save or Cancel. Segmented controls mutate owner state without a global animation and apply animation only to their local selection surface. Time-zone rows moved into a cached, lazy, searchable selection sheet.

## Prevention Rule

SwiftUI forms must not construct, compare, encode, or persist whole-feature snapshots from `body` or `onChange` input expressions. Reusable controls must not wrap external state mutations in broad animation transactions, and large reference catalogs must not be eagerly materialized inside scrolling form content.

## Regression Safeguard

`AddRoutineFeatureTests.recurrenceChangesScheduleDraftAutosaveThroughTheFeature` verifies reducer-owned draft scheduling, and `addTaskInteractionWorkStaysOutOfTheSwiftUIRenderPath` guards the structural render-path, animation-scope, and lazy-catalog boundaries.
